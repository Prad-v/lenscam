import Foundation

public enum CaptureGenre: String, Codable, CaseIterable, Sendable, Identifiable {
    case photography
    case portrait
    case landscape
    case nature
    case food
    case wildlife
    case sport
    case cinematic

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .photography: "Photography"
        case .portrait: "Portrait"
        case .landscape: "Landscape"
        case .nature: "Nature"
        case .food: "Food"
        case .wildlife: "Wildlife"
        case .sport: "Sport"
        case .cinematic: "Cinematic"
        }
    }

    public var pipeline: CaptureProfile {
        switch self {
        case .photography, .landscape, .nature, .food, .wildlife, .sport:
            .master
        case .portrait:
            .clarity
        case .cinematic:
            .interview
        }
    }

    public var burstCount: Int {
        self == .sport ? 4 : 1
    }

    public var watchesSharpCrop: Bool {
        self == .wildlife || self == .nature || self == .food
    }

    public var showsGrid: Bool {
        self == .landscape
    }

    /// The optical stop to select for this genre. Nil leaves the current zoom alone.
    public func preferredZoom(among stops: [Double]) -> Double? {
        let clean = stops.filter { $0 > 0 }.sorted()
        guard let first = clean.first else { return nil }
        switch self {
        case .photography, .cinematic:
            return nil
        case .landscape, .nature, .food:
            return first
        case .portrait, .sport:
            return clean.min(by: { abs($0 - 2) < abs($1 - 2) }) ?? first
        case .wildlife:
            return clean.last ?? first
        }
    }
}

public struct SceneReading: Equatable, Sendable {
    public var horizonDegrees: Double?
    public var personDetected: Bool
    public var animalDetected: Bool

    public init(horizonDegrees: Double? = nil, personDetected: Bool = false, animalDetected: Bool = false) {
        self.horizonDegrees = horizonDegrees
        self.personDetected = personDetected
        self.animalDetected = animalDetected
    }

    public var measurement: String {
        let horizon: String
        if let horizonDegrees {
            horizon = String(format: "%.1f°", horizonDegrees)
        } else {
            horizon = "not measured"
        }
        return """
        Person detected: \(personDetected ? "yes" : "no")
        Animal detected: \(animalDetected ? "yes" : "no")
        Horizon: \(horizon)
        """
    }
}

public enum GenreDialMotion {
    /// Index of the genre that should lock to the center after a horizontal drag.
    /// Positive `translation` means the finger moved right, which reveals earlier genres.
    public static func index(from current: Int, translation: Double, slot: Double, count: Int) -> Int {
        guard count > 0 else { return 0 }
        let bounded = min(max(current, 0), count - 1)
        guard slot > 0 else { return bounded }
        let steps = Int((-translation / slot).rounded(.toNearestOrAwayFromZero))
        return min(max(bounded + steps, 0), count - 1)
    }
}

public enum GenreCoach {
    /// One line when the frame is not ready for the genre. Nil when it is ready.
    public static func line(
        genre: CaptureGenre,
        zoom: ZoomReading,
        scene: SceneReading = SceneReading(),
        stops: [Double] = []
    ) -> String? {
        guard zoom.band != .notMeasured else { return nil }

        switch genre {
        case .wildlife:
            if zoom.band == .digital || zoom.band == .pastSharpCrop {
                return "Wildlife stays on the telephoto. Move closer."
            }
        case .nature:
            if zoom.band == .pastSharpCrop || zoom.band == .digital {
                return "Nature is past the sharp crop. Move closer."
            }
        case .sport:
            if zoom.band == .digital || zoom.band == .pastSharpCrop {
                return "Sport wants an optical lens so the shutter can stay fast."
            }
        case .portrait:
            let hasPortraitLens = stops.contains { abs($0 - 2) < 0.15 }
            if hasPortraitLens, abs(zoom.factor - 2) > 0.35 {
                return "Portrait wants the 2× lens."
            }
        case .landscape:
            if let horizon = scene.horizonDegrees, abs(horizon) > 1.5 {
                return String(format: "Horizon is %.0f° off.", abs(horizon))
            }
        case .food:
            if zoom.band == .digital || zoom.band == .pastSharpCrop {
                return "Food wants the plate closer, on the wide lens."
            }
            if let wide = stops.first, stops.count > 1, abs(zoom.factor - wide) > 0.2 {
                return "Food stays on the wide lens."
            }
        case .photography, .cinematic:
            break
        }
        return nil
    }
}
