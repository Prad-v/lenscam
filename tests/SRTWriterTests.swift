import XCTest
@testable import LenscamCore

final class SRTWriterTests: XCTestCase {
    func testTimestampAndBilingualCue() {
        XCTAssertEqual(SRTWriter.timestamp(1.5), "00:00:01,500")
        let text = SRTWriter.render([
            TranscriptSegment(start: 1.5, end: 2, text: "Hello", translation: "Hola"),
        ])
        XCTAssertEqual(
            text,
            """
            1
            00:00:01,500 --> 00:00:02,000
            Hello
            Hola

            """
        )
    }

    func testEndBeforeStartIsOrdered() {
        let text = SRTWriter.render([
            TranscriptSegment(start: 4, end: 1, text: "Late"),
        ])
        XCTAssertTrue(text.contains("00:00:01,000 --> 00:00:04,000"))
    }
}
