import AppIntents
import Foundation

struct SearchCodeIntent: AppIntent {
    static var title: LocalizedStringResource = "Search Code"
    static var description = IntentDescription("Search the last Spotlight Code index dump and open a match.")
    static var openAppWhenRun: Bool = true

    @Parameter(title: "Query")
    var query: String

    static var parameterSummary: some ParameterSummary {
        Summary("Search code for \(\.$query)")
    }

    func perform() async throws -> some IntentResult & ProvidesDialog {
        let hits = IndexIO.search(query)
        guard let hit = hits.first else {
            return .result(dialog: IntentDialog("No matches for \(query)"))
        }
        await MainActor.run {
            CodeOpener.open(path: hit.path, line: hit.line)
        }
        return .result(dialog: IntentDialog("Opened \(hit.path)"))
    }
}
