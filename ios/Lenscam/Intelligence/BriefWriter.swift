import Foundation
import FoundationModels
import LenscamCore

enum BriefWriter {
    struct Outcome {
        var brief: CaptureBrief?
        var message: String?
    }

    static func write(profile: CaptureProfile, sourceText: String, transcript: String) async -> Outcome {
        let material = [sourceText, transcript]
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .joined(separator: "\n\n")

        if material.isEmpty {
            return Outcome(
                brief: CaptureBrief(
                    title: "Nothing readable",
                    summary: "No text or transcript was available, so Lenscam did not ask the on-device model to describe the picture.",
                    actions: [],
                    model: "lenscam-guard"
                ),
                message: "No readable text, so no model description was written."
            )
        }

        let model = SystemLanguageModel.default
        guard case .available = model.availability else {
            return Outcome(brief: nil, message: availabilityMessage(model.availability))
        }

        let session = LanguageModelSession(instructions: """
        You write short professional notes for a photographer. \
        Use only the text the user supplies. Do not invent people, places, measurements, or events. \
        If the text is fragmentary, say so.
        """)
        let prompt = """
        Profile: \(profile.title)
        Text:
        \(material)
        """
        do {
            let response = try await session.respond(to: prompt, generating: ShotBrief.self)
            return Outcome(
                brief: CaptureBrief(
                    title: response.content.title,
                    summary: response.content.summary,
                    actions: response.content.actions,
                    model: "apple-foundation-on-device"
                ),
                message: "Brief written on device from the captured text."
            )
        } catch {
            return Outcome(brief: nil, message: error.localizedDescription)
        }
    }

    static func availabilityMessage(_ availability: SystemLanguageModel.Availability) -> String {
        switch availability {
        case .available:
            "On-device model ready."
        case .unavailable(.deviceNotEligible):
            "This iPhone cannot run Apple Intelligence. Capture, reading, and translation still work."
        case .unavailable(.appleIntelligenceNotEnabled):
            "Turn on Apple Intelligence to write briefs. Capture, reading, and translation still work."
        case .unavailable(.modelNotReady):
            "Apple Intelligence is still preparing. Capture and reading still work."
        @unknown default:
            "Apple Intelligence is unavailable. Capture and reading still work."
        }
    }
}

@Generable
struct ShotBrief {
    @Guide(description: "A title of twelve words or fewer, drawn only from the supplied text")
    var title: String

    @Guide(description: "Two sentences a colleague can act on, grounded only in the supplied text")
    var summary: String

    @Guide(description: "Up to five concrete next steps. Leave empty when the text does not support any.")
    var actions: [String]
}
