import Foundation

public enum LookFilter: String, Codable, CaseIterable, Sendable, Identifiable {
    case none
    case vivid
    case warm
    case cool
    case fade
    case dramatic
    case grain
    case mono

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .none: "None"
        case .vivid: "Vivid"
        case .warm: "Warm"
        case .cool: "Cool"
        case .fade: "Fade"
        case .dramatic: "Drama"
        case .grain: "Grain"
        case .mono: "Mono"
        }
    }
}

public struct LookRecipe: Equatable, Sendable {
    public var exposure: Double
    public var contrast: Double
    public var highlights: Double
    public var shadows: Double
    public var color: Double
    public var warmth: Double
    public var sharp: Double
    public var vignette: Double
    public var mono: Bool
    public var grain: Double

    public static let neutral = LookRecipe(
        exposure: 0, contrast: 0, highlights: 0, shadows: 0,
        color: 0, warmth: 0, sharp: 0, vignette: 0, mono: false, grain: 0
    )

    public var isNeutral: Bool {
        exposure == 0 && contrast == 0 && highlights == 0 && shadows == 0
            && color == 0 && warmth == 0 && sharp == 0 && vignette == 0 && !mono && grain == 0
    }

    public init(
        exposure: Double, contrast: Double, highlights: Double, shadows: Double,
        color: Double, warmth: Double, sharp: Double, vignette: Double, mono: Bool,
        grain: Double = 0
    ) {
        self.exposure = exposure
        self.contrast = contrast
        self.highlights = highlights
        self.shadows = shadows
        self.color = color
        self.warmth = warmth
        self.sharp = sharp
        self.vignette = vignette
        self.mono = mono
        self.grain = grain
    }

    func scaled(by intensity: Double) -> LookRecipe {
        let amount = min(1, max(0, intensity))
        return LookRecipe(
            exposure: exposure * amount,
            contrast: contrast * amount,
            highlights: highlights * amount,
            shadows: shadows * amount,
            color: color * amount,
            warmth: warmth * amount,
            sharp: sharp * amount,
            vignette: vignette * amount,
            mono: mono && amount >= 0.5,
            grain: grain * amount
        )
    }
}

public enum LookFilters {
    /// Tone grades only. They do not invent detail.
    public static func recipe(_ filter: LookFilter, intensity: Double) -> LookRecipe {
        base(filter).scaled(by: filter == .none ? 0 : intensity)
    }

    private static func base(_ filter: LookFilter) -> LookRecipe {
        switch filter {
        case .none:
            .neutral
        case .vivid:
            LookRecipe(exposure: 0.05, contrast: 0.45, highlights: -0.1, shadows: 0.15, color: 0.55, warmth: 0.05, sharp: 0.2, vignette: 0, mono: false)
        case .warm:
            LookRecipe(exposure: 0.05, contrast: 0.15, highlights: 0, shadows: 0.1, color: 0.1, warmth: 0.65, sharp: 0, vignette: 0.1, mono: false)
        case .cool:
            LookRecipe(exposure: 0, contrast: 0.12, highlights: 0, shadows: 0, color: 0.05, warmth: -0.55, sharp: 0.05, vignette: 0, mono: false)
        case .fade:
            LookRecipe(exposure: 0.08, contrast: -0.35, highlights: -0.2, shadows: 0.15, color: -0.25, warmth: 0.1, sharp: 0, vignette: 0.15, mono: false)
        case .dramatic:
            LookRecipe(exposure: -0.05, contrast: 0.7, highlights: -0.25, shadows: 0.35, color: -0.1, warmth: 0, sharp: 0.15, vignette: 0.45, mono: false)
        case .grain:
            LookRecipe(exposure: 0.02, contrast: 0.08, highlights: 0, shadows: 0, color: -0.06, warmth: 0.08, sharp: 0, vignette: 0.05, mono: false, grain: 0.72)
        case .mono:
            LookRecipe(exposure: 0.05, contrast: 0.3, highlights: -0.05, shadows: 0.1, color: 0, warmth: 0, sharp: 0.1, vignette: 0.2, mono: true)
        }
    }
}

public enum EnhanceCopy {
    public static let recipe = LookRecipe(
        exposure: 0.04, contrast: 0.28, highlights: -0.08, shadows: 0.2,
        color: 0.1, warmth: 0, sharp: 0.15, vignette: 0, mono: false
    )

    public static let note = "A labeled enhance copy. Contrast and edges were adjusted. Detail was not invented, and the master file was not changed."

    /// The enhance file is a sidecar. Evidence never gets one, and a grade the user already chose is not replaced.
    public static func shouldWrite(enabled: Bool, allowsEdits: Bool, gradeIsNeutral: Bool, hasFramedCopy: Bool) -> Bool {
        enabled && allowsEdits && gradeIsNeutral && !hasFramedCopy
    }
}

/// A filter file the photographer imported. Saturation, contrast, color temperature, and film grain only.
public struct ImportedLook: Codable, Equatable, Hashable, Identifiable, Sendable {
    public var id: String
    public var title: String
    public var saturation: Double
    public var contrast: Double
    public var temperature: Double
    public var grain: Double

    public init(
        id: String = UUID().uuidString,
        title: String,
        saturation: Double,
        contrast: Double,
        temperature: Double,
        grain: Double
    ) {
        self.id = id
        self.title = title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "Imported" : title
        self.saturation = Self.clampSigned(saturation)
        self.contrast = Self.clampSigned(contrast)
        self.temperature = Self.clampSigned(temperature)
        self.grain = Self.clampGrain(grain)
    }

    private enum CodingKeys: String, CodingKey {
        case id, title, saturation, contrast, temperature, grain
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let hasLook = container.contains(.saturation) || container.contains(.contrast)
            || container.contains(.temperature) || container.contains(.grain) || container.contains(.title)
        guard hasLook else {
            throw DecodingError.dataCorrupted(.init(codingPath: decoder.codingPath, debugDescription: "Missing filter fields."))
        }
        self.init(
            id: try container.decodeIfPresent(String.self, forKey: .id) ?? UUID().uuidString,
            title: try container.decodeIfPresent(String.self, forKey: .title) ?? "Imported",
            saturation: try container.decodeIfPresent(Double.self, forKey: .saturation) ?? 0,
            contrast: try container.decodeIfPresent(Double.self, forKey: .contrast) ?? 0,
            temperature: try container.decodeIfPresent(Double.self, forKey: .temperature) ?? 0,
            grain: try container.decodeIfPresent(Double.self, forKey: .grain) ?? 0
        )
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(title, forKey: .title)
        try container.encode(saturation, forKey: .saturation)
        try container.encode(contrast, forKey: .contrast)
        try container.encode(temperature, forKey: .temperature)
        try container.encode(grain, forKey: .grain)
    }

    public func recipe(intensity: Double) -> LookRecipe {
        let amount = min(1, max(0, intensity))
        return LookRecipe(
            exposure: 0,
            contrast: contrast * amount,
            highlights: 0,
            shadows: 0,
            color: saturation * amount,
            warmth: temperature * amount,
            sharp: 0,
            vignette: 0,
            mono: false,
            grain: grain * amount
        )
    }

    private static func clampSigned(_ value: Double) -> Double {
        min(1, max(-1, value))
    }

    private static func clampGrain(_ value: Double) -> Double {
        min(1, max(0, value))
    }
}

public enum LookImportError: Error, Equatable {
    case unreadable
}

public enum LookImport {
    /// One filter object, or a list of them. Unknown files are refused.
    public static func decode(_ data: Data) throws -> [ImportedLook] {
        let decoder = JSONDecoder()
        if let many = try? decoder.decode([ImportedLook].self, from: data), !many.isEmpty {
            return many
        }
        if let one = try? decoder.decode(ImportedLook.self, from: data) {
            return [one]
        }
        throw LookImportError.unreadable
    }
}
