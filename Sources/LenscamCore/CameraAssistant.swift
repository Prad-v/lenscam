import Foundation

public enum LensSwitching: String, Codable, CaseIterable, Sendable, Identifiable {
    case automatic
    case hold
    case nearest

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .automatic: "Auto"
        case .hold: "Hold"
        case .nearest: "Nearest"
        }
    }
}

public enum FocusTuning: String, Codable, CaseIterable, Sendable, Identifiable {
    case nearer
    case standard
    case farther

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .nearer: "Nearer"
        case .standard: "Standard"
        case .farther: "Farther"
        }
    }

    /// Lens position when this bias replaces continuous autofocus. Nil keeps autofocus.
    /// Zero is the closest the lens can hold.
    public var lensPosition: Double? {
        switch self {
        case .nearer: 0.2
        case .standard: nil
        case .farther: 0.82
        }
    }
}

public struct AssistantSettings: Codable, Equatable, Sendable {
    public var quickTapShutter: Bool
    public var lensSwitching: LensSwitching
    public var focusTuning: FocusTuning
    public var palmGesture: Bool
    public var voiceShutter: Bool
    public var floatingShutter: Bool
    public var floatX: Double
    public var floatY: Double

    public static let standard = AssistantSettings(
        quickTapShutter: false,
        lensSwitching: .automatic,
        focusTuning: .standard,
        palmGesture: false,
        voiceShutter: false,
        floatingShutter: false,
        floatX: 0.82,
        floatY: 0.46
    )

    public init(
        quickTapShutter: Bool,
        lensSwitching: LensSwitching,
        focusTuning: FocusTuning,
        palmGesture: Bool,
        voiceShutter: Bool,
        floatingShutter: Bool,
        floatX: Double,
        floatY: Double
    ) {
        self.quickTapShutter = quickTapShutter
        self.lensSwitching = lensSwitching
        self.focusTuning = focusTuning
        self.palmGesture = palmGesture
        self.voiceShutter = voiceShutter
        self.floatingShutter = floatingShutter
        self.floatX = FloatingShutter.clamped(floatX)
        self.floatY = FloatingShutter.clamped(floatY)
    }

    public static func decode(_ data: Data) -> AssistantSettings {
        guard let settings = try? JSONDecoder().decode(AssistantSettings.self, from: data) else {
            return .standard
        }
        return AssistantSettings(
            quickTapShutter: settings.quickTapShutter,
            lensSwitching: settings.lensSwitching,
            focusTuning: settings.focusTuning,
            palmGesture: settings.palmGesture,
            voiceShutter: settings.voiceShutter,
            floatingShutter: settings.floatingShutter,
            floatX: settings.floatX,
            floatY: settings.floatY
        )
    }
}

public enum LensSwitchPolicy {
    /// The zoom to apply when a genre is chosen. Nil leaves the current lens alone.
    public static func zoom(preferred: Double?, current: Double, stops: [Double], mode: LensSwitching) -> Double? {
        switch mode {
        case .hold:
            return nil
        case .automatic:
            return preferred
        case .nearest:
            return nearest(to: preferred ?? current, stops: stops)
        }
    }

    /// Pinch zoom. Nearest lands on an optical stop. The other modes keep the requested factor.
    public static func pinchResult(_ factor: Double, stops: [Double], mode: LensSwitching) -> Double {
        guard mode == .nearest else { return factor }
        return nearest(to: factor, stops: stops) ?? factor
    }

    public static func nearest(to factor: Double, stops: [Double]) -> Double? {
        let clean = stops.filter { $0 > 0 }
        return clean.min(by: { abs($0 - factor) < abs($1 - factor) })
    }
}

public enum QuickTap {
    public static func captures(enabled: Bool, recording: Bool, busy: Bool) -> Bool {
        enabled && !recording && !busy
    }
}

public enum FloatingShutter {
    public static func clamped(_ value: Double) -> Double {
        min(0.92, max(0.08, value))
    }
}

public enum VoiceCue {
    public static let phrases = ["cheese", "shoot", "capture", "smile"]
    public static let cooldown: TimeInterval = 2

    public static func matches(_ text: String) -> Bool {
        let folded = text.lowercased()
        return phrases.contains { folded.contains($0) }
    }
}

public struct HandSpread: Equatable, Sendable {
    public var tipCount: Int
    public var span: Double

    public init(tipCount: Int, span: Double) {
        self.tipCount = tipCount
        self.span = span
    }
}

public enum PalmPolicy {
    public static let requiredTips = 5
    public static let minimumSpan = 0.18
    public static let framesNeeded = 4
    public static let cooldown: TimeInterval = 1.6

    public static func isOpen(_ hand: HandSpread) -> Bool {
        hand.tipCount >= requiredTips && hand.span >= minimumSpan
    }

    public static func advanced(open: Bool, streak: Int) -> Int {
        open ? streak + 1 : 0
    }

    public static func ready(streak: Int, lastFire: Date?, now: Date) -> Bool {
        guard streak >= framesNeeded else { return false }
        if let lastFire, now.timeIntervalSince(lastFire) < cooldown { return false }
        return true
    }
}
