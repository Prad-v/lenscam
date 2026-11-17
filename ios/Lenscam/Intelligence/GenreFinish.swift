import AVFoundation
import CoreImage
import Foundation
import ImageIO
import LenscamCore
import UIKit
import Vision

enum GenreFinish {
    static func scene(from data: Data) -> SceneReading {
        guard let image = CIImage(data: data) else { return SceneReading() }
        let handler = VNImageRequestHandler(ciImage: image, options: [:])
        let horizon = VNDetectHorizonRequest()
        let people = VNDetectHumanRectanglesRequest()
        let animals = VNRecognizeAnimalsRequest()
        try? handler.perform([horizon, people, animals])
        let degrees = horizon.results?.first.map { Double($0.angle) * 180 / .pi }
        return SceneReading(
            horizonDegrees: degrees,
            personDetected: !(people.results?.isEmpty ?? true),
            animalDetected: !(animals.results?.isEmpty ?? true)
        )
    }

    static func sharpness(_ data: Data) -> Double {
        guard let image = CIImage(data: data),
              let edges = CIFilter(name: "CIEdges"),
              let average = CIFilter(name: "CIAreaAverage") else { return 0 }
        edges.setValue(image, forKey: kCIInputImageKey)
        edges.setValue(1.5, forKey: kCIInputIntensityKey)
        guard let edged = edges.outputImage else { return 0 }
        average.setValue(edged, forKey: kCIInputImageKey)
        average.setValue(CIVector(cgRect: edged.extent), forKey: kCIInputExtentKey)
        guard let pixel = average.outputImage else { return 0 }
        var bitmap = [UInt8](repeating: 0, count: 4)
        CIContext().render(
            pixel,
            toBitmap: &bitmap,
            rowBytes: 4,
            bounds: CGRect(x: 0, y: 0, width: 1, height: 1),
            format: .RGBA8,
            colorSpace: CGColorSpaceCreateDeviceRGB()
        )
        return Double(bitmap[0]) + Double(bitmap[1]) + Double(bitmap[2])
    }

    static func copy(genre: CaptureGenre, data: Data, scene: SceneReading) -> GenreCopy? {
        guard let input = CIImage(data: data) else { return nil }
        let rendered: CIImage
        let kind: DerivativeKind
        let filename: String
        let note: String
        switch genre {
        case .photography, .cinematic:
            return nil
        case .portrait:
            rendered = tone(input, exposure: 0.12, contrast: 1.03, saturation: 0.94)
            kind = .portrait
            filename = "portrait.jpg"
            note = "Portrait copy. Skin was not sharpened. The master was not changed."
        case .landscape:
            rendered = straighten(tone(input, exposure: 0, contrast: 1.06, saturation: 1.08), degrees: scene.horizonDegrees)
            kind = .landscape
            filename = "landscape.jpg"
            note = "Landscape copy. Horizon straightened when it was measured, with modest contrast. The master was not changed."
        case .nature:
            rendered = sharpen(input, radius: 1.2, intensity: 0.35)
            kind = .nature
            filename = "nature.jpg"
            note = "Nature copy. A little edge contrast on the frame. Detail was not invented. The master was not changed."
        case .food:
            rendered = warmPlate(tone(input, exposure: 0.06, contrast: 1.06, saturation: 1.16))
            kind = .food
            filename = "food.jpg"
            note = "Food copy. A little warmth and color on the plate. The master was not changed."
        case .wildlife, .sport:
            rendered = sharpen(input, radius: 1.1, intensity: 0.3)
            kind = .subject
            filename = "subject.jpg"
            note = "Subject copy. Modest edge contrast only. Fur, feathers, and faces were not reconstructed. The master was not changed."
        }
        guard let jpeg = jpegData(rendered) else { return nil }
        return GenreCopy(kind: kind, filename: filename, note: note, jpeg: jpeg)
    }

    static func letterboxJPEG(_ image: CGImage) -> Data? {
        let source = CIImage(cgImage: image)
        let width = source.extent.width
        let height = source.extent.height
        guard width > 1, height > 1 else { return nil }
        let target = width / 2.39
        let cropHeight = min(height, target)
        let y = source.extent.minY + (height - cropHeight) / 2
        let cropped = source.cropped(to: CGRect(x: source.extent.minX, y: y, width: width, height: cropHeight))
        return jpegData(cropped)
    }

    private static func tone(_ input: CIImage, exposure: Double, contrast: Double, saturation: Double) -> CIImage {
        var image = input
        if let filter = CIFilter(name: "CIExposureAdjust") {
            filter.setValue(image, forKey: kCIInputImageKey)
            filter.setValue(exposure, forKey: kCIInputEVKey)
            image = filter.outputImage ?? image
        }
        if let filter = CIFilter(name: "CIColorControls") {
            filter.setValue(image, forKey: kCIInputImageKey)
            filter.setValue(contrast, forKey: kCIInputContrastKey)
            filter.setValue(saturation, forKey: kCIInputSaturationKey)
            image = filter.outputImage ?? image
        }
        return image
    }

    private static func warmPlate(_ input: CIImage) -> CIImage {
        guard let filter = CIFilter(name: "CITemperatureAndTint") else { return input }
        filter.setValue(input, forKey: kCIInputImageKey)
        filter.setValue(CIVector(x: 6500, y: 0), forKey: "inputNeutral")
        filter.setValue(CIVector(x: 5200, y: 0), forKey: "inputTargetNeutral")
        return filter.outputImage ?? input
    }

    private static func sharpen(_ input: CIImage, radius: Double, intensity: Double) -> CIImage {
        guard let filter = CIFilter(name: "CIUnsharpMask") else { return input }
        filter.setValue(input, forKey: kCIInputImageKey)
        filter.setValue(radius, forKey: kCIInputRadiusKey)
        filter.setValue(intensity, forKey: kCIInputIntensityKey)
        return filter.outputImage ?? input
    }

    private static func straighten(_ input: CIImage, degrees: Double?) -> CIImage {
        guard let degrees, abs(degrees) > 0.4, abs(degrees) < 12,
              let filter = CIFilter(name: "CIStraightenFilter") else { return input }
        filter.setValue(input, forKey: kCIInputImageKey)
        filter.setValue(-degrees * .pi / 180, forKey: kCIInputAngleKey)
        return filter.outputImage ?? input
    }

    private static func jpegData(_ image: CIImage) -> Data? {
        guard let colorSpace = CGColorSpace(name: CGColorSpace.sRGB) else { return nil }
        return CIContext().jpegRepresentation(
            of: image,
            colorSpace: colorSpace,
            options: [kCGImageDestinationLossyCompressionQuality as CIImageRepresentationOption: 0.92]
        )
    }
}

struct GenreCopy {
    var kind: DerivativeKind
    var filename: String
    var note: String
    var jpeg: Data
}
