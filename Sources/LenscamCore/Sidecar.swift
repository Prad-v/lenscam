import Foundation

public struct GeoMark: Codable, Equatable, Sendable {
    public var latitude: Double
    public var longitude: Double
    public var horizontalAccuracy: Double

    public init(latitude: Double, longitude: Double, horizontalAccuracy: Double) {
        self.latitude = latitude
        self.longitude = longitude
        self.horizontalAccuracy = horizontalAccuracy
    }
}

public struct TextReading: Codable, Equatable, Sendable {
    public var sourceText: String
    public var sourceLanguage: String?
    public var translatedText: String?
    public var targetLanguage: String?
    public var barcodes: [String]

    public init(
        sourceText: String,
        sourceLanguage: String? = nil,
        translatedText: String? = nil,
        targetLanguage: String? = nil,
        barcodes: [String] = []
    ) {
        self.sourceText = sourceText
        self.sourceLanguage = sourceLanguage
        self.translatedText = translatedText
        self.targetLanguage = targetLanguage
        self.barcodes = barcodes
    }
}

public struct TranscriptSegment: Codable, Equatable, Sendable {
    public var start: Double
    public var end: Double
    public var text: String
    public var translation: String?

    public init(start: Double, end: Double, text: String, translation: String? = nil) {
        self.start = start
        self.end = end
        self.text = text
        self.translation = translation
    }
}

public struct CaptureBrief: Codable, Equatable, Sendable {
    public var title: String
    public var summary: String
    public var actions: [String]
    public var model: String

    public init(title: String, summary: String, actions: [String], model: String) {
        self.title = title
        self.summary = summary
        self.actions = actions
        self.model = model
    }
}

public enum DerivativeKind: String, Codable, Sendable {
    case preview
    case clarity
    case portrait
    case landscape
    case nature
    case subject
    case burst
    case letterbox
    case look
    case enhance
    case food
}

public struct DerivativeNote: Codable, Equatable, Sendable {
    public var kind: DerivativeKind
    public var filename: String
    public var note: String

    public init(kind: DerivativeKind, filename: String, note: String) {
        self.kind = kind
        self.filename = filename
        self.note = note
    }
}

public struct CaptureSidecar: Codable, Equatable, Sendable, Identifiable {
    public static let currentVersion = 1

    public var version: Int
    public var id: UUID
    public var profile: CaptureProfile
    public var genre: CaptureGenre?
    public var createdAt: Date
    public var masterFilename: String
    public var masterSHA256: String
    public var codec: String
    public var zoom: ZoomReading
    public var evidenceLocked: Bool
    public var location: GeoMark?
    public var reading: TextReading?
    public var transcript: [TranscriptSegment]
    public var brief: CaptureBrief?
    public var derivatives: [DerivativeNote]
    public var note: String

    public init(
        version: Int = CaptureSidecar.currentVersion,
        id: UUID,
        profile: CaptureProfile,
        genre: CaptureGenre? = nil,
        createdAt: Date,
        masterFilename: String,
        masterSHA256: String,
        codec: String,
        zoom: ZoomReading,
        evidenceLocked: Bool,
        location: GeoMark? = nil,
        reading: TextReading? = nil,
        transcript: [TranscriptSegment] = [],
        brief: CaptureBrief? = nil,
        derivatives: [DerivativeNote] = [],
        note: String = ""
    ) {
        self.version = version
        self.id = id
        self.profile = profile
        self.genre = genre
        self.createdAt = createdAt
        self.masterFilename = masterFilename
        self.masterSHA256 = masterSHA256
        self.codec = codec
        self.zoom = zoom
        self.evidenceLocked = evidenceLocked
        self.location = location
        self.reading = reading
        self.transcript = transcript
        self.brief = brief
        self.derivatives = derivatives
        self.note = note
    }
}

public enum SidecarCodec {
    public static func encode(_ sidecar: CaptureSidecar) throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        return try encoder.encode(sidecar)
    }

    public static func decode(_ data: Data) throws -> CaptureSidecar {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode(CaptureSidecar.self, from: data)
    }
}
