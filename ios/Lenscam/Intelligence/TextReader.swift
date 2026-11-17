import Foundation
import Vision

enum TextReader {
    struct Result: Sendable {
        var text: String
        var barcodes: [String]
    }

    static func read(data: Data) throws -> Result {
        let textRequest = VNRecognizeTextRequest()
        textRequest.recognitionLevel = .accurate
        textRequest.usesLanguageCorrection = true
        let barcodeRequest = VNDetectBarcodesRequest()
        let handler = VNImageRequestHandler(data: data)
        try handler.perform([textRequest, barcodeRequest])

        let observations = textRequest.results ?? []
        let lines = observations.sorted { lhs, rhs in
            if abs(lhs.boundingBox.midY - rhs.boundingBox.midY) > 0.02 {
                return lhs.boundingBox.midY > rhs.boundingBox.midY
            }
            return lhs.boundingBox.minX < rhs.boundingBox.minX
        }
        .compactMap { $0.topCandidates(1).first?.string }

        let codes = (barcodeRequest.results ?? []).compactMap(\.payloadStringValue)
        return Result(text: lines.joined(separator: "\n"), barcodes: codes)
    }
}
