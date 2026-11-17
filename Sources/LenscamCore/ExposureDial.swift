import Foundation

public enum ExposureDial {
    /// 0 is the bottom of the track, the darkest bias. 1 is the top, the brightest.
    public static func fraction(bias: Double, min minBias: Double, max maxBias: Double) -> Double {
        let span = maxBias - minBias
        guard span > 0.001 else { return 0.5 }
        return min(1, max(0, (bias - minBias) / span))
    }

    public static func bias(fraction: Double, min minBias: Double, max maxBias: Double) -> Double {
        let span = maxBias - minBias
        guard span > 0.001 else { return minBias }
        let t = min(1, max(0, fraction))
        return minBias + span * t
    }

    public static func label(_ bias: Double) -> String {
        if abs(bias) < 0.05 { return "0" }
        return String(format: "%+.1f", locale: Locale(identifier: "en_US_POSIX"), bias)
    }
}
