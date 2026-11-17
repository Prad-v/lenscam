import Foundation
import FoundationModels

enum SuggestionPhrase {
    /// Restates a settings instruction. Returns nil when the model is unavailable or adds facts.
    static func rephrase(_ sentence: String) async -> String? {
        let model = SystemLanguageModel.default
        guard case .available = model.availability else { return nil }
        let session = LanguageModelSession(instructions: """
        Restate the camera instruction in one short sentence. \
        Keep every number. Do not add people, places, weather, or measurements that are not in the instruction.
        """)
        do {
            let response = try await session.respond(to: sentence, generating: RestatedLine.self)
            let line = response.content.sentence.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !line.isEmpty, line.count < 160, numbers(in: line).isSubset(of: numbers(in: sentence)) else {
                return nil
            }
            return line
        } catch {
            return nil
        }
    }

    private static func numbers(in text: String) -> Set<String> {
        let pattern = #/\d+(?:\.\d+)?/#
        return Set(text.matches(of: pattern).map(\.output.description))
    }
}

@Generable
struct RestatedLine {
    @Guide(description: "One short sentence that restates the camera instruction and adds nothing")
    var sentence: String
}
