import Foundation
import NaturalLanguage
import Translation

struct LanguageChoice: Identifiable, Hashable {
    var id: String
    var name: String
}

enum LanguageChoices {
    static let all: [LanguageChoice] = [
        LanguageChoice(id: "en", name: "English"),
        LanguageChoice(id: "es", name: "Spanish"),
        LanguageChoice(id: "fr", name: "French"),
        LanguageChoice(id: "de", name: "German"),
        LanguageChoice(id: "pt", name: "Portuguese"),
        LanguageChoice(id: "ja", name: "Japanese"),
        LanguageChoice(id: "zh-Hans", name: "Chinese (Simplified)"),
        LanguageChoice(id: "ko", name: "Korean"),
        LanguageChoice(id: "ar", name: "Arabic"),
        LanguageChoice(id: "hi", name: "Hindi"),
    ]

    static func language(for id: String) -> Locale.Language {
        Locale.Language(identifier: id)
    }
}

enum OnDeviceTranslator {
    struct Result: Sendable {
        var text: String
        var source: String
        var target: String
    }

    enum Failure: LocalizedError {
        case packMissing

        var errorDescription: String? {
            "That language is not installed yet. Use Translate to download it, then try again."
        }
    }

    static func translate(_ text: String, to target: Locale.Language) async throws -> Result {
        let recognizer = NLLanguageRecognizer()
        recognizer.processString(text)
        let source = Locale.Language(identifier: recognizer.dominantLanguage?.rawValue ?? "en")
        let availability = LanguageAvailability()
        let status = await availability.status(from: source, to: target)
        guard status == .installed else { throw Failure.packMissing }
        let session = TranslationSession(installedSource: source, target: target)
        try await session.prepareTranslation()
        let response = try await session.translate(text)
        return Result(
            text: response.targetText,
            source: response.sourceLanguage.minimalIdentifier,
            target: response.targetLanguage.minimalIdentifier
        )
    }
}
