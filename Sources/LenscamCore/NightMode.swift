import Foundation

public enum NightChoice: String, Sendable, Equatable, CaseIterable {
    case off
    case auto
    case manual

    public var title: String {
        switch self {
        case .off: "Off"
        case .auto: "Auto"
        case .manual: "Time"
        }
    }
}

public struct NightPlan: Equatable, Sendable {
    /// The shutter may stay open for `seconds`. False when the lens cannot hold a night exposure.
    public var longExposure: Bool
    public var seconds: Double
    /// Ask the device to brighten a dark preview when it supports low-light boost.
    public var boost: Bool

    public var label: String {
        guard longExposure else { return boost ? "Boost" : "Off" }
        return NightMode.durationLabel(seconds)
    }

    public init(longExposure: Bool, seconds: Double, boost: Bool) {
        self.longExposure = longExposure
        self.seconds = seconds
        self.boost = boost
    }
}

public enum NightMode {
    public static let minimumSeconds = 0.5
    public static let maximumSeconds = 3.0
    /// Auto turns on when the preview is darker than this.
    public static let engageBelow = 0.32
    /// Auto stays on until the preview is brighter than this.
    public static let releaseAbove = 0.40

    public static func durationLabel(_ seconds: Double) -> String {
        guard seconds > 0 else { return "Off" }
        if seconds >= 0.95 {
            return String(format: "%.0fs", seconds.rounded())
        }
        let denominator = max(1, Int((1.0 / seconds).rounded()))
        return "1/\(denominator)s"
    }

    /// What night mode should do for this scene. A format maximum of 0 means the lens is not measured yet, so night stays off.
    public static func plan(
        choice: NightChoice,
        manualSeconds: Double,
        brightness: Double?,
        formatMaxSeconds: Double,
        currentlyEngaged: Bool = false
    ) -> NightPlan {
        guard formatMaxSeconds > 0 else {
            return NightPlan(longExposure: false, seconds: 0, boost: false)
        }
        let ceiling = min(maximumSeconds, formatMaxSeconds)
        switch choice {
        case .off:
            return NightPlan(longExposure: false, seconds: 0, boost: false)
        case .manual:
            return held(seconds: manualSeconds, ceiling: ceiling, boostWhenShort: true)
        case .auto:
            guard let brightness else {
                return NightPlan(longExposure: false, seconds: 0, boost: false)
            }
            let limit = currentlyEngaged ? releaseAbove : engageBelow
            guard brightness < limit else {
                return NightPlan(longExposure: false, seconds: 0, boost: false)
            }
            return held(seconds: autoSeconds(brightness), ceiling: ceiling, boostWhenShort: true)
        }
    }

    public static func caption(choice: NightChoice, plan: NightPlan) -> String {
        switch choice {
        case .off:
            return "Night mode is off."
        case .auto where plan.longExposure:
            return "Auto. The shutter can stay open for \(plan.label)."
        case .manual where plan.longExposure:
            return "The shutter can stay open for \(plan.label)."
        case .auto where plan.boost, .manual where plan.boost:
            return "Low-light boost is on. This lens cannot hold a longer shutter."
        case .auto:
            return "Auto stays off until the scene is dark."
        case .manual:
            return "Night mode is off."
        }
    }

    private static func held(seconds: Double, ceiling: Double, boostWhenShort: Bool) -> NightPlan {
        let wanted = min(maximumSeconds, max(minimumSeconds, seconds))
        guard ceiling + 0.001 >= minimumSeconds else {
            return NightPlan(longExposure: false, seconds: 0, boost: boostWhenShort)
        }
        return NightPlan(longExposure: true, seconds: min(wanted, ceiling), boost: true)
    }

    private static func autoSeconds(_ brightness: Double) -> Double {
        if brightness < 0.12 { return 3 }
        if brightness < 0.20 { return 2 }
        if brightness < 0.28 { return 1 }
        return minimumSeconds
    }
}
