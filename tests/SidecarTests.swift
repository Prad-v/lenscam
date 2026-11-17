import XCTest
@testable import LenscamCore

final class SidecarTests: XCTestCase {
    func testRoundTripKeepsTheEvidenceLockAndHash() throws {
        let sidecar = CaptureSidecar(
            id: UUID(uuidString: "AAAAAAAA-BBBB-CCCC-DDDD-EEEEEEEEEEEE")!,
            profile: .evidence,
            createdAt: Date(timeIntervalSince1970: 1_700_000_000),
            masterFilename: "master.dng",
            masterSHA256: "abc123",
            codec: "dng",
            zoom: ZoomReading(factor: 2, band: .optical, coach: "Optical. This frame is the lens."),
            evidenceLocked: true,
            location: GeoMark(latitude: 37.7, longitude: -122.4, horizontalAccuracy: 8),
            reading: TextReading(sourceText: "VIN 123", sourceLanguage: "en", barcodes: ["123"]),
            note: "Imported still."
        )

        let decoded = try SidecarCodec.decode(SidecarCodec.encode(sidecar))
        XCTAssertEqual(decoded, sidecar)
        XCTAssertTrue(decoded.evidenceLocked)
        XCTAssertNil(decoded.brief)
        XCTAssertEqual(decoded.masterSHA256, "abc123")
    }
}
