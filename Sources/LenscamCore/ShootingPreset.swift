import Foundation

public struct ShootingPreset: Codable, Equatable, Identifiable, Hashable, Sendable {
    public var id: UUID
    public var name: String
    public var genre: CaptureGenre
    public var filter: LookFilter
    public var intensity: Double
    public var manual: ManualSetup
    public var raw: RawChoice
    public var builtIn: Bool

    public init(
        id: UUID,
        name: String,
        genre: CaptureGenre,
        filter: LookFilter,
        intensity: Double,
        manual: ManualSetup,
        raw: RawChoice,
        builtIn: Bool
    ) {
        self.id = id
        self.name = name
        self.genre = genre
        self.filter = filter
        self.intensity = intensity
        self.manual = manual
        self.raw = raw
        self.builtIn = builtIn
    }
}

public enum PresetLibrary {
    public static let daylight = UUID(uuidString: "4E1A7C10-0000-4000-8000-000000000001")!
    public static let indoor = UUID(uuidString: "4E1A7C10-0000-4000-8000-000000000002")!
    public static let action = UUID(uuidString: "4E1A7C10-0000-4000-8000-000000000003")!
    public static let vivid = UUID(uuidString: "4E1A7C10-0000-4000-8000-000000000004")!
    public static let mono = UUID(uuidString: "4E1A7C10-0000-4000-8000-000000000005")!

    public static let builtIn: [ShootingPreset] = [
        ShootingPreset(id: daylight, name: "Daylight", genre: .photography, filter: .none, intensity: 1, manual: .automatic, raw: .auto, builtIn: true),
        ShootingPreset(
            id: indoor,
            name: "Indoor",
            genre: .photography,
            filter: .warm,
            intensity: 0.7,
            manual: ManualSetup(
                exposureManual: false, iso: 100, shutterSeconds: 1.0 / 60,
                focusLocked: false, lensPosition: 0.6,
                whiteBalanceManual: true, temperature: 3800
            ),
            raw: .auto,
            builtIn: true
        ),
        ShootingPreset(id: action, name: "Action", genre: .sport, filter: .none, intensity: 1, manual: .automatic, raw: .off, builtIn: true),
        ShootingPreset(id: vivid, name: "Vivid", genre: .photography, filter: .vivid, intensity: 0.85, manual: .automatic, raw: .auto, builtIn: true),
        ShootingPreset(id: mono, name: "Mono", genre: .photography, filter: .mono, intensity: 1, manual: .automatic, raw: .auto, builtIn: true),
    ]
}

public enum SceneGuide {
    public static func suggestion(
        face: Bool?,
        animal: Bool?,
        horizon: Double?,
        current: CaptureGenre
    ) -> CaptureGenre? {
        if face == true, current != .portrait {
            return .portrait
        }
        if animal == true, current != .wildlife, current != .nature {
            return .wildlife
        }
        if let horizon, abs(horizon) < 12, face != true, current != .landscape {
            return .landscape
        }
        return nil
    }

    public static func sentence(for genre: CaptureGenre) -> String {
        switch genre {
        case .portrait:
            "A person is in the frame. Switch to Portrait?"
        case .wildlife:
            "An animal is in the frame. Switch to Wildlife?"
        case .landscape:
            "The horizon is in the frame. Switch to Landscape?"
        default:
            "Switch to \(genre.title)?"
        }
    }
}
