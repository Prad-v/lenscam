import XCTest
@testable import LenscamCore

final class CameraAssistantTests: XCTestCase {
    func testLensHoldLeavesTheZoomAlone() {
        XCTAssertNil(LensSwitchPolicy.zoom(preferred: 1, current: 5, stops: [1, 2, 5], mode: .hold))
        XCTAssertEqual(LensSwitchPolicy.zoom(preferred: 1, current: 5, stops: [1, 2, 5], mode: .automatic), 1)
        XCTAssertEqual(LensSwitchPolicy.zoom(preferred: nil, current: 2.2, stops: [1, 2, 5], mode: .nearest), 2)
    }

    func testNearestPinchLandsOnAStop() {
        XCTAssertEqual(LensSwitchPolicy.pinchResult(1.4, stops: [1, 2, 5], mode: .nearest), 1)
        XCTAssertEqual(LensSwitchPolicy.pinchResult(1.7, stops: [1, 2, 5], mode: .automatic), 1.7, accuracy: 0.001)
        XCTAssertNil(LensSwitchPolicy.nearest(to: 2, stops: []))
    }

    func testQuickTapStaysQuietWhileBusyOrRecording() {
        XCTAssertTrue(QuickTap.captures(enabled: true, recording: false, busy: false))
        XCTAssertFalse(QuickTap.captures(enabled: true, recording: true, busy: false))
        XCTAssertFalse(QuickTap.captures(enabled: true, recording: false, busy: true))
        XCTAssertFalse(QuickTap.captures(enabled: false, recording: false, busy: false))
    }

    func testFocusTuningBias() {
        XCTAssertEqual(FocusTuning.nearer.lensPosition, 0.2)
        XCTAssertNil(FocusTuning.standard.lensPosition)
        XCTAssertEqual(FocusTuning.farther.lensPosition, 0.82)
    }

    func testFloatingShutterStaysOnScreen() {
        XCTAssertEqual(FloatingShutter.clamped(-1), 0.08, accuracy: 0.001)
        XCTAssertEqual(FloatingShutter.clamped(4), 0.92, accuracy: 0.001)
        XCTAssertEqual(FloatingShutter.clamped(0.4), 0.4, accuracy: 0.001)
        let settings = AssistantSettings(
            quickTapShutter: true,
            lensSwitching: .hold,
            focusTuning: .nearer,
            palmGesture: true,
            voiceShutter: false,
            floatingShutter: true,
            floatX: 3,
            floatY: -1
        )
        XCTAssertEqual(settings.floatX, 0.92, accuracy: 0.001)
        XCTAssertEqual(settings.floatY, 0.08, accuracy: 0.001)
    }

    func testVoiceCueMatchesTheShutterWords() {
        XCTAssertTrue(VoiceCue.matches("say cheese"))
        XCTAssertTrue(VoiceCue.matches("SHOOT"))
        XCTAssertFalse(VoiceCue.matches("hello there"))
    }

    func testPalmNeedsAnOpenHandAndAPause() {
        let open = HandSpread(tipCount: 5, span: 0.3)
        let fist = HandSpread(tipCount: 2, span: 0.05)
        XCTAssertTrue(PalmPolicy.isOpen(open))
        XCTAssertFalse(PalmPolicy.isOpen(fist))
        XCTAssertEqual(PalmPolicy.advanced(open: true, streak: 3), 4)
        XCTAssertEqual(PalmPolicy.advanced(open: false, streak: 3), 0)
        let now = Date(timeIntervalSince1970: 1_000)
        XCTAssertFalse(PalmPolicy.ready(streak: 2, lastFire: nil, now: now))
        XCTAssertTrue(PalmPolicy.ready(streak: 4, lastFire: nil, now: now))
        XCTAssertFalse(PalmPolicy.ready(streak: 4, lastFire: now.addingTimeInterval(-0.4), now: now))
        XCTAssertTrue(PalmPolicy.ready(streak: 4, lastFire: now.addingTimeInterval(-2), now: now))
    }

    func testFoodSuggestsTheWideLens() {
        let zoom = ZoomMeter.reading(zoomFactor: 5, opticalStops: [1, 2, 5], highResolutionCrop: true, pastSharpCrop: false)
        let advice = SettingAdvisor.recommend(genre: .food, zoom: zoom, scene: LiveScene(), stops: [1, 2, 5])
        XCTAssertEqual(advice?.action, .zoom)
        XCTAssertEqual(advice?.zoomFactor, 1)
        let wide = ZoomMeter.reading(zoomFactor: 1, opticalStops: [1, 2, 5], highResolutionCrop: true, pastSharpCrop: false)
        XCTAssertNil(SettingAdvisor.recommend(genre: .food, zoom: wide, scene: LiveScene(), stops: [1, 2, 5])?.zoomFactor)
    }
}
