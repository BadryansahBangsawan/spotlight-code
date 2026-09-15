import Foundation

enum Support {
    static let bundleId = "engineer.badry.spotlightcode"
    static let displayName = "Spotlight Code"
    static let defaultsPrefix = bundleId + "."
    static let excludeGlobsKey = defaultsPrefix + "excludeGlobs"
    static let defaultExcludeGlobs = ["*.generated.swift", "*.min.js"]
    static let fileCap = 5000
    static let skipDirNames: Set<String> = [
        "node_modules", ".git", ".build", "DerivedData", "dist", ".next", "Pods"
    ]
    static let codeExtensions: Set<String> = [
        "swift", "ts", "tsx", "js", "jsx", "py", "go", "rs", "rb",
        "java", "kt", "c", "h", "cc", "cpp", "m", "mm", "md", "json"
    ]
    static let defaultRootCandidates = [
        "Developer", "Downloads/project-fun", "Documents", "src"
    ]

    static var supportDirectory: URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Application Support/\(displayName)", isDirectory: true)
    }

    static var rootsURL: URL { supportDirectory.appendingPathComponent("roots.json") }
    static var indexURL: URL { supportDirectory.appendingPathComponent("index.json") }

    static func ensureSupportDirectory() throws {
        try FileManager.default.createDirectory(at: supportDirectory, withIntermediateDirectories: true)
    }

    static func excludeGlobs() -> [String] {
        if UserDefaults.standard.object(forKey: excludeGlobsKey) == nil {
            return defaultExcludeGlobs
        }
        return UserDefaults.standard.stringArray(forKey: excludeGlobsKey) ?? []
    }

    static func setExcludeGlobs(_ globs: [String]) {
        UserDefaults.standard.set(globs, forKey: excludeGlobsKey)
    }

    static func matchesGlob(_ filename: String, glob: String) -> Bool {
        let escaped = NSRegularExpression.escapedPattern(for: glob)
            .replacingOccurrences(of: "\\*", with: ".*")
            .replacingOccurrences(of: "\\?", with: ".")
        return filename.range(of: "^\(escaped)$", options: [.regularExpression, .caseInsensitive]) != nil
    }

    static func defaultRootsIfMissing() -> [RootEntry] {
        let home = FileManager.default.homeDirectoryForCurrentUser
        var roots: [RootEntry] = []
        for rel in defaultRootCandidates {
            let url = home.appendingPathComponent(rel, isDirectory: true)
            var isDir: ObjCBool = false
            if FileManager.default.fileExists(atPath: url.path, isDirectory: &isDir), isDir.boolValue {
                roots.append(RootEntry(path: url.path))
            }
        }
        return roots
    }
}

struct RootEntry: Codable, Identifiable, Hashable {
    var path: String
    var id: String { path }
}

struct IndexHit: Codable, Identifiable, Hashable {
    var path: String
    var line: Int
    var snippet: String
    var id: String { "\(path):\(line):\(snippet)" }
}

struct IndexedFile: Codable, Identifiable, Hashable {
    var path: String
    var title: String
    var relativePath: String
    var snippet: String
    var id: String { path }
}

struct IndexDump: Codable {
    var fileCount: Int
    var lastIndexed: Date?
    var capped: Bool
    var files: [IndexedFile]
    var hits: [IndexHit]
}
