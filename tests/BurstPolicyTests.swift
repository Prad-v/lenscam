import XCTest
@testable import LenscamCore

final class BurstPolicyTests: XCTestCase {
    func testStillProfilesCanHoldForABurst() {
        XCTAssertTrue(BurstPolicy.allowsHold(profile: .master))
        XCTAssertTrue(BurstPolicy.allowsHold(profile: .clarity))
        XCTAssertTrue(BurstPolicy.allowsHold(profile: .read))
        XCTAssertTrue(BurstPolicy.allowsHold(profile: .evidence))
        XCTAssertFalse(BurstPolicy.allowsHold(profile: .interview))
    }

    func testNightBurstStaysShort() {
        XCTAssertEqual(BurstPolicy.frameLimit(nightEngaged: false), 12)
        XCTAssertEqual(BurstPolicy.frameLimit(nightEngaged: true), 4)
    }

    func testSharpestFrameWinsAndATieKeepsTheEarlierOne() {
        XCTAssertNil(BurstPolicy.sharpestIndex(in: []))
        XCTAssertEqual(BurstPolicy.sharpestIndex(in: [0.2, 0.9, 0.4]), 1)
        XCTAssertEqual(BurstPolicy.sharpestIndex(in: [0.5, 0.5, 0.1]), 0)
    }
}
