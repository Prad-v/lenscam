import Foundation

public struct ZoomReading: Codable, Equatable, Sendable {
    public enum Band: String, Codable, Sendable {
        case optical
        case sensorCrop
        case digital
        case pastSharpCrop
        case notMeasured

        public var title: String {
            switch self {
            case .optical: "Optical"
            case .sensorCrop: "Sensor crop"
            case .digital: "Digital"
            case .pastSharpCrop: "Past sharp crop"
            case .notMeasured: "Not measured"
            }
        }
    }

    public var factor: Double
    public var band: Band
    public var coach: String

    public init(factor: Double, band: Band, coach: String) {
        self.factor = factor
        self.band = band
        self.coach = coach
    }

    public static let imported = ZoomReading(
        factor: 1,
        band: .notMeasured,
        coach: "Imported still. Zoom quality was not measured, because this file did not come from the Lenscam meter."
    )

    public var factorLabel: String {
        String(format: "%.1f×", factor)
    }
}

public enum ZoomMeter {
    /// `opticalStops` are the virtual-device switch-over factors, such as 1, 2, and 5.
    /// A stop within 3% is optical. Up to 2× past that stop is a sensor crop when the
    /// phone has a high-resolution sensor. Further than that is digital, or past the
    /// sharp crop when the profile is Zoom or Read.
    public static func reading(
        zoomFactor: Double,
        opticalStops: [Double],
        highResolutionCrop: Bool,
        pastSharpCrop: Bool
    ) -> ZoomReading {
        guard zoomFactor > 0 else {
            return ZoomReading(
                factor: zoomFactor,
                band: .notMeasured,
                coach: "Zoom factor is not available yet."
            )
        }

        var stops = opticalStops.filter { $0 > 0 }.sorted()
        if !stops.contains(where: { abs($0 - 1) < 0.02 }) {
            stops.append(1)
            stops.sort()
        }

        let base = stops.last(where: { $0 <= zoomFactor + 0.001 }) ?? stops[0]
        let ratio = zoomFactor / base
        let band: ZoomReading.Band
        let coach: String

        if ratio <= 1.03 {
            band = .optical
            coach = "Optical. This frame is the lens."
        } else if highResolutionCrop && ratio <= 2 {
            band = .sensorCrop
            coach = "Sensor crop. Detail comes from the full sensor, not from interpolation."
        } else if pastSharpCrop {
            band = .pastSharpCrop
            coach = "Past the sharp crop. Move closer for faces and products. Read still extracts only the text that is in the master."
        } else {
            band = .digital
            coach = "Digital zoom. Move closer if the subject must stay sharp."
        }

        return ZoomReading(factor: zoomFactor, band: band, coach: coach)
    }
}
