import XCTest
@testable import LenscamCore

final class NightModeTests: XCTestCase {
    func testAutoStaysOffInDaylight() {
        let plan = NightMode.plan(choice: .auto, manualSeconds: 1, brightness: 0.7, formatMaxSeconds: 3)
        XCTAssertFalse(plan.longExposure)
        XCTAssertFalse(plan.boost)
        XCTAssertEqual(NightMode.caption(choice: .auto, plan: plan), "Auto stays off until the scene is dark.")
    }

    func testAutoHoldsTheShutterWhenTheSceneIsDark() {
        let plan = NightMode.plan(choice: .auto, manualSeconds: 1, brightness: 0.1, formatMaxSeconds: 4)
        XCTAssertTrue(plan.longExposure)
        XCTAssertEqual(plan.seconds, 3, accuracy: 0.001)
        XCTAssertTrue(plan.boost)
        XCTAssertEqual(plan.label, "3s")
    }

    func testAutoStepsTheDurationWithBrightness() {
        XCTAssertEqual(NightMode.plan(choice: .auto, manualSeconds: 1, brightness: 0.18, formatMaxSeconds: 3).seconds, 2, accuracy: 0.001)
        XCTAssertEqual(NightMode.plan(choice: .auto, manualSeconds: 1, brightness: 0.24, formatMaxSeconds: 3).seconds, 1, accuracy: 0.001)
        XCTAssertEqual(NightMode.plan(choice: .auto, manualSeconds: 1, brightness: 0.30, formatMaxSeconds: 3).seconds, 0.5, accuracy: 0.001)
        XCTAssertEqual(NightMode.plan(choice: .auto, manualSeconds: 1, brightness: 0.30, formatMaxSeconds: 3).label, "1/2s")
    }

    func testAutoDoesNotInventAReading() {
        let plan = NightMode.plan(choice: .auto, manualSeconds: 1, brightness: nil, formatMaxSeconds: 3)
        XCTAssertFalse(plan.longExposure)
        XCTAssertFalse(plan.boost)
    }

    func testAutoStaysOffUntilTheLensIsMeasured() {
        let plan = NightMode.plan(choice: .auto, manualSeconds: 1, brightness: 0.1, formatMaxSeconds: 0)
        XCTAssertFalse(plan.longExposure)
        XCTAssertFalse(plan.boost)
    }

    func testAutoHysteresisKeepsADimSceneEngaged() {
        let plan = NightMode.plan(
            choice: .auto,
            manualSeconds: 1,
            brightness: 0.36,
            formatMaxSeconds: 3,
            currentlyEngaged: true
        )
        XCTAssertTrue(plan.longExposure)
        XCTAssertEqual(plan.seconds, 0.5, accuracy: 0.001)
    }

    func testOffIgnoresADarkScene() {
        let plan = NightMode.plan(choice: .off, manualSeconds: 2, brightness: 0.05, formatMaxSeconds: 3)
        XCTAssertFalse(plan.longExposure)
        XCTAssertFalse(plan.boost)
        XCTAssertEqual(NightMode.caption(choice: .off, plan: plan), "Night mode is off.")
    }

    func testManualClampsToTheLens() {
        let plan = NightMode.plan(choice: .manual, manualSeconds: 3, brightness: 0.9, formatMaxSeconds: 1)
        XCTAssertTrue(plan.longExposure)
        XCTAssertEqual(plan.seconds, 1, accuracy: 0.001)
        XCTAssertEqual(plan.label, "1s")
    }

    func testManualFallsBackToBoostWhenTheLensIsShort() {
        let plan = NightMode.plan(choice: .manual, manualSeconds: 2, brightness: 0.1, formatMaxSeconds: 0.2)
        XCTAssertFalse(plan.longExposure)
        XCTAssertTrue(plan.boost)
        XCTAssertEqual(plan.label, "Boost")
    }

    func testExposureTrackMapsUpToBrighter() {
        XCTAssertEqual(ExposureDial.fraction(bias: 2, min: -2, max: 2), 1, accuracy: 0.001)
        XCTAssertEqual(ExposureDial.fraction(bias: -2, min: -2, max: 2), 0, accuracy: 0.001)
        XCTAssertEqual(ExposureDial.bias(fraction: 1, min: -2, max: 2), 2, accuracy: 0.001)
        XCTAssertEqual(ExposureDial.bias(fraction: 0.25, min: -2, max: 2), -1, accuracy: 0.001)
        XCTAssertEqual(ExposureDial.label(0.02), "0")
        XCTAssertEqual(ExposureDial.label(0.7), "+0.7")
        XCTAssertEqual(ExposureDial.label(-1.3), "-1.3")
    }
}
