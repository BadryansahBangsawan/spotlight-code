import SwiftUI

struct RootView: View {
    @EnvironmentObject private var store: IndexStore
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var statusText: String {
        let count = store.dump.fileCount
        if let last = store.dump.lastIndexed {
            let formatter = DateFormatter()
            formatter.dateStyle = .short
            formatter.timeStyle = .short
            return "\(count) files, \(formatter.string(from: last))"
        }
        return "\(count) files, never indexed"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            if let loadError = store.loadError {
                Label(loadError, systemImage: "exclamationmark.triangle.fill")
                    .foregroundStyle(.red)
                    .fixedSize(horizontal: false, vertical: true)
            }
            if let banner = store.errorBanner {
                Label(banner, systemImage: "exclamationmark.triangle.fill")
                    .foregroundStyle(.red)
                    .fixedSize(horizontal: false, vertical: true)
            }

            HStack {
                Button(store.isIndexing ? "Indexing…" : "Index now") {
                    store.indexNow()
                }
                .disabled(store.isIndexing || store.roots.isEmpty)
                if store.isIndexing {
                    ProgressView()
                        .controlSize(.small)
                }
                Spacer()
            }

            Text(statusText)
                .font(.system(.caption))
                .foregroundStyle(.secondary)

            TextField("Search", text: $store.query)
                .textFieldStyle(.roundedBorder)

            if store.roots.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Add a folder that contains source files.")
                    Button("Add folder") { store.addRoot() }
                }
            } else if store.dump.fileCount == 0 && !store.isIndexing && store.query.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Index a folder to search source files.")
                    Button("Index now") { store.indexNow() }
                        .disabled(store.isIndexing)
                }
            } else if !store.query.isEmpty && store.results.isEmpty {
                Text("No matches.")
                    .foregroundStyle(.secondary)
            } else if !store.query.isEmpty {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 6) {
                        ForEach(store.results.prefix(80)) { hit in
                            Button {
                                CodeOpener.open(path: hit.path, line: hit.line)
                            } label: {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text((hit.path as NSString).lastPathComponent)
                                        .font(.system(.body, design: .monospaced))
                                    Text("\(hit.path):\(hit.line)")
                                        .font(.system(.caption, design: .monospaced))
                                        .foregroundStyle(.secondary)
                                        .lineLimit(1)
                                    Text(hit.snippet)
                                        .font(.system(.caption))
                                        .foregroundStyle(.secondary)
                                        .lineLimit(2)
                                }
                                .frame(maxWidth: .infinity, alignment: .leading)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                .frame(maxHeight: 220)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text("Open Spotlight")
                    .font(.system(.subheadline, weight: .medium))
                Text("Cmd-Space and type the filename")
                    .font(.system(.caption))
                    .foregroundStyle(.secondary)
            }
        }
        .funPanel()
        .background(.regularMaterial)
        .animation(reduceMotion ? nil : FunTheme.spring, value: store.isIndexing)
        .animation(reduceMotion ? nil : FunTheme.spring, value: store.dump.fileCount)
        .animation(reduceMotion ? nil : FunTheme.spring, value: store.query)
        .onAppear { store.load() }
    }
}
