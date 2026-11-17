import XCTest
@testable import LenscamCore

final class SettingAdvisorTests: XCTestCase {
    private let stops = [1.0, 2.0, 5.0]

    func testDarkFaceRaisesExposure() {
        let zoom = optical(1)
        let scene = LiveScene(brightness: 0.2, faceDetected: true, exposureBias: 0)
        let advice = SettingAdvisor.recommend(genre: .portrait, zoom: zoom, scene: scene, stops: [1])
        XCTAssertEqual(advice?.action, .exposureBias)
        XCTAssertEqual(advice?.exposureBias ?? 0, 0.7, accuracy: 0.01)
        XCTAssertEqual(advice?.sentence, "The face is dark. Raise exposure by 0.7.")
    }

    func testBrightFrameLowersExposure() {
        let scene = LiveScene(brightness: 0.9, exposureBias: 0)
        let advice = SettingAdvisor.recommend(genre: .photography, zoom: optical(1), scene: scene, stops: stops)
        XCTAssertEqual(advice?.exposureBias ?? 0, -0.7, accuracy: 0.01)
        XCTAssertTrue(advice?.sentence.contains("Lower exposure by 0.7") == true)
    }

    func testExposureStopsAtTheDeviceLimit() {
        let scene = LiveScene(brightness: 0.1, exposureBias: 1.9, maxBias: 2)
        let advice = SettingAdvisor.recommend(genre: .photography, zoom: optical(1), scene: scene, stops: stops)
        XCTAssertNil(advice)
    }

    func testPortraitAsksToReturnToTwoTimes() {
        let advice = SettingAdvisor.recommend(genre: .portrait, zoom: optical(1), scene: LiveScene(brightness: 0.5), stops: stops)
        XCTAssertEqual(advice?.action, .zoom)
        XCTAssertEqual(advice?.zoomFactor, 2)
    }

    func testReadyPortraitStaysQuiet() {
        let scene = LiveScene(brightness: 0.5, faceDetected: true, faceX: 0.5, faceY: 0.48)
        XCTAssertNil(SettingAdvisor.recommend(genre: .portrait, zoom: optical(2), scene: scene, stops: stops))
    }

    func testWildlifePastTheLensReturnsToTheTelephoto() {
        let zoom = ZoomMeter.reading(zoomFactor: 12, opticalStops: stops, highResolutionCrop: true, pastSharpCrop: true)
        let advice = SettingAdvisor.recommend(genre: .wildlife, zoom: zoom, scene: LiveScene(brightness: 0.5), stops: stops)
        XCTAssertEqual(advice?.zoomFactor, 5)
        XCTAssertEqual(advice?.sentence, "This is past the optical lens. Return to 5×.")
    }

    func testSportCapsASlowShutter() {
        let scene = LiveScene(brightness: 0.5, shutterSeconds: 1.0 / 30, minShutter: 1.0 / 8000, maxShutter: 1.0 / 3)
        let advice = SettingAdvisor.recommend(genre: .sport, zoom: optical(2), scene: scene, stops: stops)
        XCTAssertEqual(advice?.action, .shutterCap)
        XCTAssertEqual(advice?.shutterSeconds ?? 0, 1.0 / 500, accuracy: 0.0001)
        XCTAssertEqual(advice?.sentence, "Shutter is 1/30. Cap it at 1/500 so motion stays sharp.")
    }

    func testSportLeavesTheShutterAloneWhileNightIsOpen() {
        let scene = LiveScene(brightness: 0.5, shutterSeconds: 1.0 / 30, maxShutter: 1)
        let advice = SettingAdvisor.recommend(
            genre: .sport,
            zoom: optical(2),
            scene: scene,
            stops: stops,
            nightEngaged: true
        )
        XCTAssertNil(advice)
    }

    func testFastSportShutterStaysQuiet() {
        let scene = LiveScene(brightness: 0.5, shutterSeconds: 1.0 / 1000)
        XCTAssertNil(SettingAdvisor.recommend(genre: .sport, zoom: optical(2), scene: scene, stops: stops))
    }

    func testOffCenterFaceSetsTheFocusPoint() {
        let scene = LiveScene(brightness: 0.5, faceDetected: true, faceX: 0.82, faceY: 0.4)
        let advice = SettingAdvisor.recommend(genre: .portrait, zoom: optical(2), scene: scene, stops: [1])
        XCTAssertEqual(advice?.action, .focusPoint)
        XCTAssertEqual(advice?.focusX, 0.82)
        XCTAssertEqual(advice?.sentence, "Focus on the face.")
    }

    private func optical(_ factor: Double) -> ZoomReading {
        ZoomMeter.reading(zoomFactor: factor, opticalStops: stops, highResolutionCrop: true, pastSharpCrop: false)
    }
}
