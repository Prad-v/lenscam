import XCTest
@testable import LenscamCore

final class ZoomMeterTests: XCTestCase {
    private let stops = [1.0, 2.0, 5.0]

    func testOpticalAtLensStops() {
        for factor in [1.0, 2.0, 5.0] {
            let reading = ZoomMeter.reading(
                zoomFactor: factor,
                opticalStops: stops,
                highResolutionCrop: true,
                pastSharpCrop: false
            )
            XCTAssertEqual(reading.band, .optical, "expected optical at \(factor)")
        }
    }

    func testSensorCropBetweenLensesWhenHighResolution() {
        let reading = ZoomMeter.reading(
            zoomFactor: 1.5,
            opticalStops: stops,
            highResolutionCrop: true,
            pastSharpCrop: false
        )
        XCTAssertEqual(reading.band, .sensorCrop)
    }

    func testDigitalBetweenLensesWithoutHighResolution() {
        let reading = ZoomMeter.reading(
            zoomFactor: 1.5,
            opticalStops: stops,
            highResolutionCrop: false,
            pastSharpCrop: false
        )
        XCTAssertEqual(reading.band, .digital)
    }

    func testPastTheTwoTimesCropIsDigital() {
        let reading = ZoomMeter.reading(
            zoomFactor: 4.5,
            opticalStops: stops,
            highResolutionCrop: true,
            pastSharpCrop: false
        )
        XCTAssertEqual(reading.band, .digital)
    }

    func testReadAndZoomNameTheSameRegionPastSharpCrop() {
        let reading = ZoomMeter.reading(
            zoomFactor: 4.5,
            opticalStops: stops,
            highResolutionCrop: true,
            pastSharpCrop: true
        )
        XCTAssertEqual(reading.band, .pastSharpCrop)
        XCTAssertTrue(reading.coach.contains("master"))
    }

    func testMissingPrimaryStopIsInserted() {
        let reading = ZoomMeter.reading(
            zoomFactor: 1,
            opticalStops: [2, 5],
            highResolutionCrop: true,
            pastSharpCrop: false
        )
        XCTAssertEqual(reading.band, .optical)
    }

    func testNonPositiveZoomIsNotMeasured() {
        let reading = ZoomMeter.reading(
            zoomFactor: 0,
            opticalStops: stops,
            highResolutionCrop: true,
            pastSharpCrop: false
        )
        XCTAssertEqual(reading.band, .notMeasured)
    }
}
