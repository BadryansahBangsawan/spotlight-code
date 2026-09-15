import AppKit
import Foundation

enum CodeOpener {
    static let cursorCandidates = [
        "/usr/local/bin/cursor",
        "/opt/homebrew/bin/cursor"
    ]
    static let codeCandidates = [
        "/usr/local/bin/code",
        "/opt/homebrew/bin/code"
    ]

    static func open(path: String, line: Int) {
        let location = "\(path):\(line)"
        for bin in cursorCandidates where FileManager.default.isExecutableFile(atPath: bin) {
            if launch(bin, ["-g", location]) { return }
        }
        for bin in codeCandidates where FileManager.default.isExecutableFile(atPath: bin) {
            if launch(bin, ["-g", location]) { return }
        }
        if FileManager.default.isExecutableFile(atPath: "/usr/bin/xed") {
            if launch("/usr/bin/xed", ["-l", "\(line)", path]) { return }
        }
        NSWorkspace.shared.open(URL(fileURLWithPath: path))
    }

    @discardableResult
    private static func launch(_ executable: String, _ arguments: [String]) -> Bool {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: executable)
        process.arguments = arguments
        process.standardOutput = FileHandle.nullDevice
        process.standardError = FileHandle.nullDevice
        do {
            try process.run()
            return true
        } catch {
            return false
        }
    }
}
