import AppKit
import CoreSpotlight
import Foundation
import UniformTypeIdentifiers

enum IndexIO {
    static func loadDump() -> IndexDump {
        let url = Support.indexURL
        guard FileManager.default.fileExists(atPath: url.path) else {
            return IndexDump(fileCount: 0, lastIndexed: nil, capped: false, files: [], hits: [])
        }
        do {
            let data = try Data(contentsOf: url)
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            return try decoder.decode(IndexDump.self, from: data)
        } catch {
            return IndexDump(fileCount: 0, lastIndexed: nil, capped: false, files: [], hits: [])
        }
    }

    static func search(_ query: String) -> [IndexHit] {
        let dump = loadDump()
        let q = query.trimmingCharacters(in: .whitespacesAndNewlines)
        if q.isEmpty { return Array(dump.hits.prefix(80)) }
        let lowered = q.lowercased()
        var hits = dump.hits.filter {
            $0.snippet.lowercased().contains(lowered)
                || $0.path.lowercased().contains(lowered)
        }
        if hits.isEmpty {
            hits = dump.files.filter {
                $0.title.lowercased().contains(lowered)
                    || $0.relativePath.lowercased().contains(lowered)
                    || $0.path.lowercased().contains(lowered)
                    || $0.snippet.lowercased().contains(lowered)
            }.map { IndexHit(path: $0.path, line: 1, snippet: $0.snippet) }
        }
        return hits
    }
}

@MainActor
final class IndexStore: ObservableObject {
    @Published var roots: [RootEntry] = []
    @Published var dump = IndexDump(fileCount: 0, lastIndexed: nil, capped: false, files: [], hits: [])
    @Published var isIndexing = false
    @Published var query = ""
    @Published var errorBanner: String?
    @Published var loadError: String?
    @Published var excludeGlobs: [String] = Support.defaultExcludeGlobs

    var results: [IndexHit] {
        let q = query.trimmingCharacters(in: .whitespacesAndNewlines)
        if q.isEmpty { return [] }
        let lowered = q.lowercased()
        var hits = dump.hits.filter {
            $0.snippet.lowercased().contains(lowered) || $0.path.lowercased().contains(lowered)
        }
        if hits.isEmpty {
            hits = dump.files.filter {
                $0.title.lowercased().contains(lowered)
                    || $0.relativePath.lowercased().contains(lowered)
                    || $0.path.lowercased().contains(lowered)
            }.map { IndexHit(path: $0.path, line: 1, snippet: $0.snippet) }
        }
        return hits
    }

    func load() {
        excludeGlobs = Support.excludeGlobs()
        loadError = nil
        do {
            try Support.ensureSupportDirectory()
            if FileManager.default.fileExists(atPath: Support.rootsURL.path) {
                do {
                    let data = try Data(contentsOf: Support.rootsURL)
                    roots = try JSONDecoder().decode([RootEntry].self, from: data)
                } catch {
                    roots = []
                    loadError = error.localizedDescription
                }
            } else {
                roots = Support.defaultRootsIfMissing()
                try persistRoots()
            }
        } catch {
            loadError = error.localizedDescription
        }
        if FileManager.default.fileExists(atPath: Support.indexURL.path) {
            do {
                let data = try Data(contentsOf: Support.indexURL)
                let decoder = JSONDecoder()
                decoder.dateDecodingStrategy = .iso8601
                dump = try decoder.decode(IndexDump.self, from: data)
            } catch {
                dump = IndexDump(fileCount: 0, lastIndexed: nil, capped: false, files: [], hits: [])
                errorBanner = error.localizedDescription
            }
        }
    }

    func persistRoots() throws {
        try Support.ensureSupportDirectory()
        let data = try JSONEncoder().encode(roots)
        try data.write(to: Support.rootsURL, options: .atomic)
    }

    func addRoot() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = true
        panel.prompt = "Add"
        guard panel.runModal() == .OK else { return }
        for url in panel.urls {
            let entry = RootEntry(path: url.path)
            if !roots.contains(entry) {
                roots.append(entry)
            }
        }
        do {
            try persistRoots()
            errorBanner = nil
        } catch {
            errorBanner = error.localizedDescription
        }
    }

    func removeRoot(_ entry: RootEntry) {
        roots.removeAll { $0.path == entry.path }
        do {
            try persistRoots()
        } catch {
            errorBanner = error.localizedDescription
        }
    }

    func saveExcludeGlobs() {
        Support.setExcludeGlobs(excludeGlobs)
    }

    func indexNow() {
        guard !isIndexing else { return }
        isIndexing = true
        errorBanner = nil
        let rootPaths = roots.map(\.path)
        let globs = excludeGlobs
        Task.detached(priority: .userInitiated) {
            do {
                let built = try Indexer.build(roots: rootPaths, excludeGlobs: globs)
                try Support.ensureSupportDirectory()
                let encoder = JSONEncoder()
                encoder.dateEncodingStrategy = .iso8601
                let data = try encoder.encode(built)
                try data.write(to: Support.indexURL, options: .atomic)
                var spotlightError: String?
                do {
                    try await Indexer.publishSpotlight(built)
                } catch {
                    spotlightError = error.localizedDescription
                }
                let spotlightMessage = spotlightError
                await MainActor.run {
                    self.dump = built
                    self.isIndexing = false
                    if built.capped {
                        self.errorBanner = "Index capped at 5000 files"
                    } else if let spotlightMessage {
                        self.errorBanner = spotlightMessage
                    }
                }
            } catch {
                await MainActor.run {
                    self.isIndexing = false
                    self.errorBanner = error.localizedDescription
                }
            }
        }
    }
}

enum Indexer {
    static func build(roots: [String], excludeGlobs: [String]) throws -> IndexDump {
        var files: [IndexedFile] = []
        var hits: [IndexHit] = []
        var capped = false
        let fm = FileManager.default
        let skip = Support.skipDirNames
        let exts = Support.codeExtensions
        let todo = try NSRegularExpression(pattern: "TODO|FIXME|HACK")
        let sig = try NSRegularExpression(pattern: "^(func|class|struct|enum|def |fn |function |export )", options: .anchorsMatchLines)

        outer: for rootPath in roots {
            var isDir: ObjCBool = false
            guard fm.fileExists(atPath: rootPath, isDirectory: &isDir), isDir.boolValue else { continue }
            let rootURL = URL(fileURLWithPath: rootPath, isDirectory: true)
            guard let enumerator = fm.enumerator(
                at: rootURL,
                includingPropertiesForKeys: [.isRegularFileKey, .isDirectoryKey],
                options: [.skipsPackageDescendants]
            ) else { continue }

            while let url = enumerator.nextObject() as? URL {
                let name = url.lastPathComponent
                if skip.contains(name) {
                    enumerator.skipDescendants()
                    continue
                }
                let values = try url.resourceValues(forKeys: [.isRegularFileKey, .isDirectoryKey])
                if values.isDirectory == true { continue }
                guard values.isRegularFile == true else { continue }
                let ext = url.pathExtension.lowercased()
                guard exts.contains(ext) else { continue }
                if excludeGlobs.contains(where: { Support.matchesGlob(name, glob: $0) }) { continue }

                let text = (try? String(contentsOf: url, encoding: .utf8)) ?? ""
                let relative = url.path.replacingOccurrences(of: rootURL.path.hasSuffix("/") ? rootURL.path : rootURL.path + "/", with: "")
                let desc = String(text.prefix(200))
                files.append(IndexedFile(path: url.path, title: name, relativePath: relative, snippet: desc))

                let lines = text.split(omittingEmptySubsequences: false, whereSeparator: \.isNewline)
                var fileHits = 0
                for (idx, lineSub) in lines.enumerated() {
                    if fileHits >= 80 { break }
                    let line = String(lineSub)
                    let range = NSRange(line.startIndex..., in: line)
                    let isTodo = todo.firstMatch(in: line, range: range) != nil
                    let isSig = sig.firstMatch(in: line, range: range) != nil
                    if isTodo || isSig {
                        let snippet = String(line.prefix(200))
                        hits.append(IndexHit(path: url.path, line: idx + 1, snippet: snippet))
                        fileHits += 1
                    }
                }

                if files.count >= Support.fileCap {
                    capped = true
                    break outer
                }
            }
        }

        return IndexDump(
            fileCount: files.count,
            lastIndexed: Date(),
            capped: capped,
            files: files,
            hits: hits
        )
    }

    static func publishSpotlight(_ dump: IndexDump) async throws {
        let index = CSSearchableIndex.default()
        try await withCheckedThrowingContinuation { (cont: CheckedContinuation<Void, Error>) in
            index.deleteSearchableItems(withDomainIdentifiers: [Support.bundleId]) { error in
                if let error {
                    cont.resume(throwing: error)
                } else {
                    cont.resume()
                }
            }
        }
        var batch: [CSSearchableItem] = []
        batch.reserveCapacity(min(dump.files.count, 200))
        for file in dump.files {
            let attrs = CSSearchableItemAttributeSet(itemContentType: UTType.sourceCode.identifier)
            attrs.title = file.title
            attrs.displayName = file.title
            attrs.path = file.path
            let body = "\(file.title) \(file.relativePath) \(file.snippet)"
            attrs.contentDescription = String(body.prefix(200))
            let item = CSSearchableItem(
                uniqueIdentifier: file.path,
                domainIdentifier: Support.bundleId,
                attributeSet: attrs
            )
            batch.append(item)
            if batch.count >= 200 {
                try await indexItems(index, batch)
                batch.removeAll(keepingCapacity: true)
            }
        }
        if !batch.isEmpty {
            try await indexItems(index, batch)
        }
    }

    private static func indexItems(_ index: CSSearchableIndex, _ items: [CSSearchableItem]) async throws {
        try await withCheckedThrowingContinuation { (cont: CheckedContinuation<Void, Error>) in
            index.indexSearchableItems(items) { error in
                if let error {
                    cont.resume(throwing: error)
                } else {
                    cont.resume()
                }
            }
        }
    }
}
