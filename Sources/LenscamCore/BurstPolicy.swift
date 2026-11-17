import Foundation

public enum BurstPolicy {
    /// How long the shutter must stay down before a hold becomes a burst.
    public static let holdDelaySeconds = 0.32
    /// A hold stops at this many frames so one press cannot fill the phone.
    public static let maximumFrames = 12
    /// Night mode uses a long shutter, so a hold stays short.
    public static let nightFrames = 4

    /// Cinematic and Interview record. Every other shutter can burst.
    public static func allowsHold(profile: CaptureProfile) -> Bool {
        profile != .interview
    }

    public static func frameLimit(nightEngaged: Bool) -> Int {
        nightEngaged ? nightFrames : maximumFrames
    }

    /// The highest score. A tie keeps the earlier frame.
    public static func sharpestIndex(in scores: [Double]) -> Int? {
        scores.indices.max(by: { scores[$0] < scores[$1] })
    }
}
