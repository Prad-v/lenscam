import XCTest
@testable import LenscamCore

final class EvidencePolicyTests: XCTestCase {
    func testEvidenceRefusesGenerativeEdits() {
        XCTAssertFalse(EvidencePolicy.allowsGenerativeEdits(.evidence))
        XCTAssertFalse(CaptureProfile.evidence.recipe.writesBrief)
        XCTAssertFalse(CaptureProfile.evidence.recipe.writesClarityDerivative)
        XCTAssertTrue(CaptureProfile.evidence.recipe.evidenceLocked)
        XCTAssertTrue(CaptureProfile.evidence.recipe.readsText)
    }

    func testOtherProfilesMayWriteABriefBesideTheMaster() {
        XCTAssertTrue(EvidencePolicy.allowsGenerativeEdits(.brief))
        XCTAssertTrue(EvidencePolicy.allowsGenerativeEdits(.interview))
        XCTAssertTrue(CaptureProfile.brief.recipe.writesBrief)
        XCTAssertTrue(CaptureProfile.interview.recipe.transcribesSpeech)
    }

    func testNoProfileMayAlterTheMasterPixels() {
        for profile in CaptureProfile.allCases {
            XCTAssertFalse(EvidencePolicy.allowsPixelAlterationOfMaster(profile))
        }
    }

    func testClarityWritesADerivativeOnly() {
        XCTAssertTrue(CaptureProfile.clarity.recipe.writesClarityDerivative)
        XCTAssertFalse(CaptureProfile.clarity.recipe.evidenceLocked)
    }
}
