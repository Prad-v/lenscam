import Foundation

public struct ManualSetup: Codable, Equatable, Hashable, Sendable {
    public var exposureManual: Bool
    public var iso: Double
    public var shutterSeconds: Double
    public var focusLocked: Bool
    public var lensPosition: Double
    public var whiteBalanceManual: Bool
    public var temperature: Double

    public static let automatic = ManualSetup(
        exposureManual: false,
        iso: 100,
        shutterSeconds: 1.0 / 60,
        focusLocked: false,
        lensPosition: 0.6,
        whiteBalanceManual: false,
        temperature: 5600
    )

    public init(
        exposureManual: Bool,
        iso: Double,
        shutterSeconds: Double,
        focusLocked: Bool,
        lensPosition: Double,
        whiteBalanceManual: Bool,
        temperature: Double
    ) {
        self.exposureManual = exposureManual
        self.iso = iso
        self.shutterSeconds = shutterSeconds
        self.focusLocked = focusLocked
        self.lensPosition = lensPosition
        self.whiteBalanceManual = whiteBalanceManual
        self.temperature = temperature
    }
}

public enum ManualExposure {
    public static func clampISO(_ iso: Double, min minISO: Double, max maxISO: Double) -> Double {
        guard maxISO > minISO else { return max(1, iso) }
        return min(maxISO, max(minISO, iso))
    }

    public static func clampShutter(_ seconds: Double, min minSeconds: Double, max maxSeconds: Double) -> Double {
        guard maxSeconds > minSeconds, minSeconds > 0 else { return max(seconds, 0) }
        return min(maxSeconds, max(minSeconds, seconds))
    }

    public static func label(seconds: Double) -> String {
        guard seconds > 0 else { return "Auto" }
        if seconds >= 0.3 {
            return String(format: "%.1fs", locale: Locale(identifier: "en_US_POSIX"), seconds)
        }
        return "1/\(max(1, Int((1.0 / seconds).rounded())))"
    }
}

public enum FocusDial {
    public static func clamp(_ position: Double) -> Double {
        min(1, max(0, position))
    }
}

public enum WhiteBalanceDial {
    public static let minKelvin = 3000.0
    public static let maxKelvin = 8000.0

    public static func clamp(_ kelvin: Double) -> Double {
        min(maxKelvin, max(minKelvin, kelvin))
    }

    public static func label(_ kelvin: Double) -> String {
        "\(Int(clamp(kelvin).rounded()))K"
    }

    public static let named: [WhiteBalancePreset] = [
        WhiteBalancePreset(title: "Day", kelvin: 5600),
        WhiteBalancePreset(title: "Cloud", kelvin: 6500),
        WhiteBalancePreset(title: "Shade", kelvin: 7500),
        WhiteBalancePreset(title: "Tungsten", kelvin: 3200),
        WhiteBalancePreset(title: "Fluor", kelvin: 4000),
    ]
}

public struct WhiteBalancePreset: Equatable, Hashable, Identifiable, Sendable {
    public var title: String
    public var kelvin: Double
    public var id: String { title }

    public init(title: String, kelvin: Double) {
        self.title = title
        self.kelvin = kelvin
    }
}

public enum RawChoice: String, Codable, Sendable, CaseIterable {
    case off
    case auto
    case on

    public var title: String {
        switch self {
        case .off: "Off"
        case .auto: "Auto"
        case .on: "On"
        }
    }

    /// ProRAW is written only when this camera supports it and the flash will not fire.
    public static func wantsRaw(choice: RawChoice, profilePrefers: Bool, deviceSupports: Bool, flashOff: Bool) -> Bool {
        guard deviceSupports, flashOff else { return false }
        switch choice {
        case .off: return false
        case .on: return true
        case .auto: return profilePrefers
        }
    }
}
