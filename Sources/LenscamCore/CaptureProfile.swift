import Foundation

public enum CaptureProfile: String, Codable, CaseIterable, Sendable, Identifiable {
    case master
    case clarity
    case zoom
    case read
    case interview
    case brief
    case evidence

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .master: "Master"
        case .clarity: "Clarity"
        case .zoom: "Zoom"
        case .read: "Read"
        case .interview: "Interview"
        case .brief: "Brief"
        case .evidence: "Evidence"
        }
    }

    public var summary: String {
        switch self {
        case .master:
            "The largest still the camera will give, saved as the unmodified master."
        case .clarity:
            "A sharpened copy for type and edges. The master file is left as captured."
        case .zoom:
            "An honest zoom meter: optical, sensor crop, digital, or past the sharp crop."
        case .read:
            "Text and barcodes from the still, then an on-device translation when the language is installed."
        case .interview:
            "Video with the original audio, an on-device transcript, captions, and a short brief."
        case .brief:
            "A colleague note written from the text in the frame. It is stored beside the master, not inside it."
        case .evidence:
            "A locked master, a hash, optional location, and the text that was actually read. No generated brief."
        }
    }

    public var usesPastSharpCropCue: Bool {
        self == .zoom || self == .read
    }

    public var recipe: ProfileRecipe {
        switch self {
        case .master:
            ProfileRecipe(prefersProRAW: true)
        case .clarity:
            ProfileRecipe(writesClarityDerivative: true)
        case .zoom:
            ProfileRecipe()
        case .read:
            ProfileRecipe(readsText: true, translatesText: true)
        case .interview:
            ProfileRecipe(
                recordsAudio: true,
                translatesText: true,
                transcribesSpeech: true,
                writesBrief: true
            )
        case .brief:
            ProfileRecipe(readsText: true, writesBrief: true)
        case .evidence:
            ProfileRecipe(prefersProRAW: true, readsText: true, evidenceLocked: true)
        }
    }
}

public struct ProfileRecipe: Equatable, Sendable {
    public var prefersProRAW: Bool
    public var recordsAudio: Bool
    public var readsText: Bool
    public var translatesText: Bool
    public var transcribesSpeech: Bool
    public var writesBrief: Bool
    public var writesClarityDerivative: Bool
    public var evidenceLocked: Bool

    public init(
        prefersProRAW: Bool = false,
        recordsAudio: Bool = false,
        readsText: Bool = false,
        translatesText: Bool = false,
        transcribesSpeech: Bool = false,
        writesBrief: Bool = false,
        writesClarityDerivative: Bool = false,
        evidenceLocked: Bool = false
    ) {
        self.prefersProRAW = prefersProRAW
        self.recordsAudio = recordsAudio
        self.readsText = readsText
        self.translatesText = translatesText
        self.transcribesSpeech = transcribesSpeech
        self.writesBrief = writesBrief
        self.writesClarityDerivative = writesClarityDerivative
        self.evidenceLocked = evidenceLocked
    }
}
