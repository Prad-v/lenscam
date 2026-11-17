import CoreVideo
import Foundation
import LenscamCore
import Vision

enum SceneProbe {
    struct Reading: Sendable {
        var brightness: Double?
        var faceDetected: Bool
        var faceX: Double?
        var faceY: Double?
        var horizonDegrees: Double?
        var animalDetected: Bool
        var faceMeasured: Bool
        var animalMeasured: Bool
        var horizonMeasured: Bool
        var histogram: [Double]
    }

    static func read(_ buffer: CVPixelBuffer, genre: CaptureGenre, broadScene: Bool = false, histogram: Bool = false) -> Reading {
        let measured = luma(buffer, histogram: histogram)
        var faceDetected = false
        var faceX: Double?
        var faceY: Double?
        var horizon: Double?
        var animal = false

        let faces = VNDetectFaceRectanglesRequest()
        let level = VNDetectHorizonRequest()
        let animals = VNRecognizeAnimalsRequest()
        var requests: [VNRequest] = []
        let measureFaces = broadScene || genre == .portrait
        let measureHorizon = broadScene || genre == .landscape || genre == .nature
        let measureAnimals = broadScene || genre == .wildlife || genre == .nature
        if measureFaces { requests.append(faces) }
        if measureHorizon { requests.append(level) }
        if measureAnimals { requests.append(animals) }
        if !requests.isEmpty {
            let handler = VNImageRequestHandler(cvPixelBuffer: buffer, orientation: .up, options: [:])
            try? handler.perform(requests)
        }
        if let box = faces.results?.max(by: { $0.boundingBox.width * $0.boundingBox.height < $1.boundingBox.width * $1.boundingBox.height }) {
            faceDetected = true
            faceX = box.boundingBox.midX
            faceY = 1 - box.boundingBox.midY
        }
        if let angle = level.results?.first?.angle {
            horizon = Double(angle) * 180 / .pi
        }
        animal = !(animals.results?.isEmpty ?? true)
        return Reading(
            brightness: measured.brightness,
            faceDetected: faceDetected,
            faceX: faceX,
            faceY: faceY,
            horizonDegrees: horizon,
            animalDetected: animal,
            faceMeasured: measureFaces,
            animalMeasured: measureAnimals,
            horizonMeasured: measureHorizon,
            histogram: measured.histogram
        )
    }

    private static func luma(_ buffer: CVPixelBuffer, histogram: Bool) -> (brightness: Double?, histogram: [Double]) {
        CVPixelBufferLockBaseAddress(buffer, .readOnly)
        defer { CVPixelBufferUnlockBaseAddress(buffer, .readOnly) }
        let plane = CVPixelBufferGetPlaneCount(buffer) > 0 ? 0 : 0
        guard let base = CVPixelBufferGetBaseAddressOfPlane(buffer, plane) ?? CVPixelBufferGetBaseAddress(buffer) else {
            return (nil, [])
        }
        let width = CVPixelBufferGetWidthOfPlane(buffer, plane)
        let height = CVPixelBufferGetHeightOfPlane(buffer, plane)
        let rowBytes = CVPixelBufferGetBytesPerRowOfPlane(buffer, plane)
        guard width > 1, height > 1, rowBytes > 0 else { return (nil, []) }
        var sum = 0
        var count = 0
        var bins = [Int](repeating: 0, count: 16)
        let step = 28
        let pixels = base.assumingMemoryBound(to: UInt8.self)
        for y in stride(from: 0, to: height, by: step) {
            let row = y * rowBytes
            for x in stride(from: 0, to: width, by: step) {
                let value = Int(pixels[row + x])
                sum += value
                count += 1
                if histogram {
                    bins[min(15, value * 16 / 256)] += 1
                }
            }
        }
        guard count > 0 else { return (nil, []) }
        let brightness = Double(sum) / Double(count) / 255
        guard histogram else { return (brightness, []) }
        let peak = Double(bins.max() ?? 1)
        let bars = bins.map { peak > 0 ? Double($0) / peak : 0 }
        return (brightness, bars)
    }
}
