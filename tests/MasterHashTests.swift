import XCTest
@testable import LenscamCore

final class MasterHashTests: XCTestCase {
    func testKnownVector() {
        let digest = MasterHash.sha256Hex(of: Data("lenscam".utf8))
        XCTAssertEqual(digest, "777a22806d7ef1714f9822535030e7814cb0d28b0be1ae1ef78e9a3214558b8b")
    }

    func testFileMatchesBuffer() throws {
        let data = Data("master-bytes".utf8)
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try data.write(to: url)
        defer { try? FileManager.default.removeItem(at: url) }
        XCTAssertEqual(try MasterHash.sha256Hex(ofFile: url), MasterHash.sha256Hex(of: data))
    }
}
