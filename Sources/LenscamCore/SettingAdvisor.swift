import Foundation

public struct LiveScene: Equatable, Sendable {
    public var brightness: Double?
    public var faceDetected: Bool
    public var faceX: Double?
    public var faceY: Double?
    public var horizonDegrees: Double?
    public var animalDetected: Bool
    public var iso: Double
    public var shutterSeconds: Double
    public var exposureBias: Double
    public var minBias: Double
    public var maxBias: Double
    public var minShutter: Double
    public var maxShutter: Double

    public init(
        brightness: Double? = nil,
        faceDetected: Bool = false,
        faceX: Double? = nil,
        faceY: Double? = nil,
        horizonDegrees: Double? = nil,
        animalDetected: Bool = false,
        iso: Double = 0,
        shutterSeconds: Double = 0,
        exposureBias: Double = 0,
        minBias: Double = -2,
        maxBias: Double = 2,
        minShutter: Double = 1.0 / 8000,
        maxShutter: Double = 1.0 / 3
    ) {
        self.brightness = brightness
        self.faceDetected = faceDetected
        self.faceX = faceX
        self.faceY = faceY
        self.horizonDegrees = horizonDegrees
        self.animalDetected = animalDetected
        self.iso = iso
        self.shutterSeconds = shutterSeconds
        self.exposureBias = exposureBias
        self.minBias = minBias
        self.maxBias = maxBias
        self.minShutter = minShutter
        self.maxShutter = maxShutter
    }
}

public struct SettingAdjustment: Equatable, Sendable {
    public enum Action: String, Equatable, Sendable {
        case exposureBias
        case zoom
        case shutterCap
        case focusPoint
    }

    public var action: Action
    public var sentence: String
    public var exposureBias: Double?
    public var zoomFactor: Double?
    public var shutterSeconds: Double?
    public var focusX: Double?
    public var focusY: Double?

    public var id: String {
        switch action {
        case .exposureBias:
            "exposure-\(rounded(exposureBias))"
        case .zoom:
            "zoom-\(rounded(zoomFactor))"
        case .shutterCap:
            "shutter-\(rounded(shutterSeconds))"
        case .focusPoint:
            "focus-\(rounded(focusX))-\(rounded(focusY))"
        }
    }

    public init(
        action: Action,
        sentence: String,
        exposureBias: Double? = nil,
        zoomFactor: Double? = nil,
        shutterSeconds: Double? = nil,
        focusX: Double? = nil,
        focusY: Double? = nil
    ) {
        self.action = action
        self.sentence = sentence
        self.exposureBias = exposureBias
        self.zoomFactor = zoomFactor
        self.shutterSeconds = shutterSeconds
        self.focusX = focusX
        self.focusY = focusY
    }

    private func rounded(_ value: Double?) -> String {
        guard let value else { return "none" }
        return String(format: "%.2f", value)
    }
}

public enum SettingAdvisor {
    /// One camera change grounded in the live readings. Nil when the current settings already fit.
    public static func recommend(
        genre: CaptureGenre,
        zoom: ZoomReading,
        scene: LiveScene,
        stops: [Double],
        nightEngaged: Bool = false
    ) -> SettingAdjustment? {
        guard zoom.band != .notMeasured else { return nil }
        if let zoomChange = zoomRecommendation(genre: genre, zoom: zoom, stops: stops) {
            return zoomChange
        }
        if genre == .sport, !nightEngaged, let shutter = shutterRecommendation(scene) {
            return shutter
        }
        if let exposure = exposureRecommendation(genre: genre, scene: scene) {
            return exposure
        }
        if genre == .portrait, let focus = focusRecommendation(scene) {
            return focus
        }
        return nil
    }

    public static func shutterLabel(_ seconds: Double) -> String {
        guard seconds > 0 else { return "unknown" }
        if seconds >= 0.3 {
            return String(format: "%.1f s", seconds)
        }
        return "1/\(max(1, Int((1.0 / seconds).rounded())))"
    }

    private static func zoomRecommendation(
        genre: CaptureGenre,
        zoom: ZoomReading,
        stops: [Double]
    ) -> SettingAdjustment? {
        let clean = stops.filter { $0 > 0 }.sorted()
        switch genre {
        case .wildlife:
            guard zoom.band == .digital || zoom.band == .pastSharpCrop, let stop = clean.last else { return nil }
            guard abs(zoom.factor - stop) > 0.15 else { return nil }
            return SettingAdjustment(
                action: .zoom,
                sentence: "This is past the optical lens. Return to \(formatStop(stop))×.",
                zoomFactor: stop
            )
        case .portrait:
            guard clean.contains(where: { abs($0 - 2) < 0.15 }), abs(zoom.factor - 2) > 0.35 else { return nil }
            return SettingAdjustment(
                action: .zoom,
                sentence: "Portrait is sharper at 2×.",
                zoomFactor: 2
            )
        case .food:
            guard let stop = clean.first, abs(zoom.factor - stop) > 0.2 else { return nil }
            return SettingAdjustment(
                action: .zoom,
                sentence: "Food is sharper on the wide lens.",
                zoomFactor: stop
            )
        default:
            return nil
        }
    }

    private static func shutterRecommendation(_ scene: LiveScene) -> SettingAdjustment? {
        guard scene.shutterSeconds > 1.0 / 250 else { return nil }
        let target = min(scene.maxShutter, max(scene.minShutter, 1.0 / 500))
        guard scene.shutterSeconds - target > 0.0008 else { return nil }
        return SettingAdjustment(
            action: .shutterCap,
            sentence: "Shutter is \(shutterLabel(scene.shutterSeconds)). Cap it at \(shutterLabel(target)) so motion stays sharp.",
            shutterSeconds: target
        )
    }

    private static func exposureRecommendation(genre: CaptureGenre, scene: LiveScene) -> SettingAdjustment? {
        guard let brightness = scene.brightness else { return nil }
        if brightness < 0.32 {
            let target = min(scene.maxBias, scene.exposureBias + 0.7)
            guard target - scene.exposureBias >= 0.2 else { return nil }
            let who = scene.faceDetected ? "The face is dark." : "The frame is dark."
            return SettingAdjustment(
                action: .exposureBias,
                sentence: "\(who) Raise exposure by \(delta(target - scene.exposureBias)).",
                exposureBias: target
            )
        }
        if brightness > 0.82 || (genre == .landscape && brightness > 0.72) {
            let target = max(scene.minBias, scene.exposureBias - 0.7)
            guard scene.exposureBias - target >= 0.2 else { return nil }
            return SettingAdjustment(
                action: .exposureBias,
                sentence: "The frame is bright. Lower exposure by \(delta(scene.exposureBias - target)).",
                exposureBias: target
            )
        }
        return nil
    }

    private static func focusRecommendation(_ scene: LiveScene) -> SettingAdjustment? {
        guard scene.faceDetected, let x = scene.faceX, let y = scene.faceY else { return nil }
        let distance = hypot(x - 0.5, y - 0.5)
        guard distance > 0.18 else { return nil }
        return SettingAdjustment(
            action: .focusPoint,
            sentence: "Focus on the face.",
            focusX: x,
            focusY: y
        )
    }

    private static func delta(_ value: Double) -> String {
        String(format: "%.1f", value)
    }

    private static func formatStop(_ stop: Double) -> String {
        abs(stop - stop.rounded()) < 0.05 ? String(format: "%.0f", stop) : String(format: "%.1f", stop)
    }
}
