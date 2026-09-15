import AppKit
import ServiceManagement
import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var store: IndexStore
    @State private var loginError: String?
    @State private var newGlob = ""

    private var loginEnabled: Bool {
        SMAppService.mainApp.status == .enabled
    }

    var body: some View {
        Form {
            Section("Index folders") {
                if store.roots.isEmpty {
                    Text("Add a folder that contains source files.")
                    Button("Add folder") { store.addRoot() }
                } else {
                    ForEach(store.roots) { root in
                        HStack {
                            Text(root.path)
                                .font(.system(.caption, design: .monospaced))
                                .lineLimit(2)
                            Spacer()
                            Button("Remove") { store.removeRoot(root) }
                        }
                    }
                    Button("Add folder") { store.addRoot() }
                }
            }

            Section("Exclude globs") {
                ForEach(Array(store.excludeGlobs.enumerated()), id: \.offset) { index, glob in
                    HStack {
                        Text(glob)
                            .font(.system(.body, design: .monospaced))
                        Spacer()
                        Button("Remove") {
                            store.excludeGlobs.remove(at: index)
                            store.saveExcludeGlobs()
                        }
                    }
                }
                HStack {
                    TextField("*.generated.swift", text: $newGlob)
                    Button("Add") {
                        let trimmed = newGlob.trimmingCharacters(in: .whitespacesAndNewlines)
                        guard !trimmed.isEmpty else { return }
                        if !store.excludeGlobs.contains(trimmed) {
                            store.excludeGlobs.append(trimmed)
                            store.saveExcludeGlobs()
                        }
                        newGlob = ""
                    }
                }
            }

            Section("Login") {
                Toggle("Open at Login", isOn: Binding(
                    get: { loginEnabled },
                    set: { setLogin($0) }
                ))
                if let loginError {
                    Label(loginError, systemImage: "exclamationmark.triangle.fill")
                        .foregroundStyle(.red)
                }
            }

            Section {
                Button("Quit") {
                    NSApp.terminate(nil)
                }
            }
        }
        .formStyle(.grouped)
        .frame(width: 420, height: 460)
        .onAppear { store.load() }
    }

    private func setLogin(_ on: Bool) {
        do {
            if on {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
            loginError = nil
        } catch {
            loginError = error.localizedDescription
        }
    }
}
