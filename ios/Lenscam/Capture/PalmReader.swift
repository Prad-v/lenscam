import CoreVideo
import Foundation
import LenscamCore
import Vision

enum PalmReader {
    static func spread(_ buffer: CVPixelBuffer) -> HandSpread {
        let request = VNDetectHumanHandPoseRequest()
        request.maximumHandCount = 1
        let handler = VNImageRequestHandler(cvPixelBuffer: buffer, orientation: .up, options: [:])
        try? handler.perform([request])
        guard let hand = request.results?.first,
              let points = try? hand.recognizedPoints(.all) else {
            return HandSpread(tipCount: 0, span: 0)
        }
        let names: [VNHumanHandPoseObservation.JointName] = [
            .thumbTip, .indexTip, .middleTip, .ringTip, .littleTip,
        ]
        let tips = names.compactMap { points[$0] }.filter { $0.confidence > 0.3 }
        guard tips.count >= 2 else { return HandSpread(tipCount: tips.count, span: 0) }
        var span = 0.0
        for left in tips.indices {
            for right in tips.indices where right > left {
                let dx = tips[left].location.x - tips[right].location.x
                let dy = tips[left].location.y - tips[right].location.y
                span = max(span, hypot(Double(dx), Double(dy)))
            }
        }
        return HandSpread(tipCount: tips.count, span: span)
    }
}
