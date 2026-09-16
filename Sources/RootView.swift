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
        VStack(alignment: .leading, spacing: FunTheme.sectionSpacing) {
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

            VStack(alignment: .leading, spacing: FunTheme.innerSpacing) {
                HStack {
                    Button(store.isIndexing ? "Indexing…" : "Index now") {
                        store.indexNow()
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(store.isIndexing || store.roots.isEmpty)
                    if store.isIndexing {
                        ProgressView()
                            .controlSize(.small)
                    }
                }

                Text(statusText)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            ExtraSearchField(title: "Search", prompt: "filename or symbol", text: $store.query)

            if store.roots.isEmpty {
                ExtraEmptyState(
                    title: "No folders",
                    detail: "Add a folder that contains source files.",
                    actionTitle: "Add folder",
                    action: { store.addRoot() }
                )
            } else if store.dump.fileCount == 0 && !store.isIndexing && store.query.isEmpty {
                ExtraEmptyState(
                    title: "Not indexed yet",
                    detail: "Index a folder to search source files.",
                    actionTitle: "Index now",
                    action: { store.indexNow() }
                )
            } else if !store.query.isEmpty && store.results.isEmpty {
                ExtraEmptyState(
                    title: "No results",
                    detail: "No results for “\(store.query)”.",
                    actionTitle: "Clear search",
                    action: { store.query = "" }
                )
            } else if !store.query.isEmpty {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: FunTheme.innerSpacing) {
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
                                .extraRowSurface()
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                .frame(maxHeight: 280)
            }

            Text("After indexing, filenames also appear in Spotlight.")
                .font(.caption)
                .foregroundStyle(.secondary)

            ExtraSettingsFooter()
        }
        .animation(reduceMotion ? nil : FunTheme.spring, value: store.isIndexing)
        .animation(reduceMotion ? nil : FunTheme.spring, value: store.dump.fileCount)
        .animation(reduceMotion ? nil : FunTheme.spring, value: store.query)
        .funPanel()
        .onAppear { store.load() }
    }
}
