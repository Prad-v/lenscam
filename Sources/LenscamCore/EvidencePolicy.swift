import Foundation

public enum EvidencePolicy {
    public static let masterStatement = "The master file is the camera original. Lenscam does not write generative pixels into it. Readings, translations, and briefs are sidecars."

    public static func allowsGenerativeEdits(_ profile: CaptureProfile) -> Bool {
        profile != .evidence
    }

    public static func allowsPixelAlterationOfMaster(_ profile: CaptureProfile) -> Bool {
        _ = profile
        return false
    }
}
