import CoreImage
import Foundation
import ImageIO
import LenscamCore
import UIKit

enum EditTool: String, CaseIterable, Identifiable, Hashable, Sendable {
    case exposure
    case contrast
    case highlights
    case shadows
    case color
    case warmth
    case sharp
    case vignette
    case grain
    case mono

    var id: String { rawValue }

    var title: String {
        switch self {
        case .exposure: "Exposure"
        case .contrast: "Contrast"
        case .highlights: "Highlights"
        case .shadows: "Shadows"
        case .color: "Color"
        case .warmth: "Warmth"
        case .sharp: "Sharp"
        case .vignette: "Vignette"
        case .grain: "Grain"
        case .mono: "Mono"
        }
    }
}

struct PhotoGrade: Equatable, Sendable {
    var exposure = 0.0
    var contrast = 0.0
    var highlights = 0.0
    var shadows = 0.0
    var saturation = 0.0
    var warmth = 0.0
    var sharp = 0.0
    var vignette = 0.0
    var grain = 0.0
    var mono = false

    var isNeutral: Bool {
        exposure == 0 && contrast == 0 && highlights == 0 && shadows == 0
            && saturation == 0 && warmth == 0 && sharp == 0 && vignette == 0 && grain == 0 && !mono
    }

    func value(for tool: EditTool) -> Double {
        switch tool {
        case .exposure: exposure
        case .contrast: contrast
        case .highlights: highlights
        case .shadows: shadows
        case .color: saturation
        case .warmth: warmth
        case .sharp: sharp
        case .vignette: vignette
        case .grain: grain
        case .mono: mono ? 1 : 0
        }
    }

    func setting(_ tool: EditTool, to value: Double) -> PhotoGrade {
        var copy = self
        switch tool {
        case .exposure: copy.exposure = value
        case .contrast: copy.contrast = value
        case .highlights: copy.highlights = value
        case .shadows: copy.shadows = value
        case .color: copy.saturation = value
        case .warmth: copy.warmth = value
        case .sharp: copy.sharp = value
        case .vignette: copy.vignette = value
        case .grain: copy.grain = value
        case .mono: copy.mono = value > 0.5
        }
        return copy
    }

    init() {}

    init(_ recipe: LookRecipe) {
        exposure = recipe.exposure
        contrast = recipe.contrast
        highlights = recipe.highlights
        shadows = recipe.shadows
        saturation = recipe.color
        warmth = recipe.warmth
        sharp = recipe.sharp
        vignette = recipe.vignette
        grain = recipe.grain
        mono = recipe.mono
    }

    static func stops(for tool: EditTool) -> [Double] {
        switch tool {
        case .exposure:
            [-2, -1.5, -1, -0.5, 0, 0.5, 1, 1.5, 2]
        case .contrast, .highlights, .shadows, .color, .warmth:
            [-1, -0.5, 0, 0.5, 1]
        case .sharp, .vignette, .grain:
            [0, 0.25, 0.5, 0.75, 1]
        case .mono:
            [0, 1]
        }
    }

    static func range(for tool: EditTool) -> ClosedRange<Double> {
        let stops = stops(for: tool)
        let lower = stops.first ?? 0
        let upper = stops.last ?? 1
        return lower...upper
    }

    static func label(tool: EditTool, value: Double) -> String {
        switch tool {
        case .exposure:
            value == 0 ? "0" : String(format: "%+.1f", value)
        case .mono:
            value > 0.5 ? "Mono" : "Color"
        default:
            "\(Int((value * 100).rounded()))"
        }
    }
}

enum PhotoGradeRender {
    private static let context = CIContext(options: [.cacheIntermediates: false])

    static func apply(_ image: CIImage, _ grade: PhotoGrade) -> CIImage {
        guard !grade.isNeutral else { return image }
        var result = image
        if grade.exposure != 0, let filter = CIFilter(name: "CIExposureAdjust") {
            filter.setValue(result, forKey: kCIInputImageKey)
            filter.setValue(grade.exposure, forKey: kCIInputEVKey)
            result = filter.outputImage ?? result
        }
        if grade.contrast != 0 || grade.saturation != 0 || grade.mono, let filter = CIFilter(name: "CIColorControls") {
            filter.setValue(result, forKey: kCIInputImageKey)
            filter.setValue(1 + grade.contrast * 0.35, forKey: kCIInputContrastKey)
            filter.setValue(grade.mono ? 0 : max(0, 1 + grade.saturation), forKey: kCIInputSaturationKey)
            result = filter.outputImage ?? result
        }
        if grade.highlights != 0 || grade.shadows != 0, let filter = CIFilter(name: "CIHighlightShadowAdjust") {
            filter.setValue(result, forKey: kCIInputImageKey)
            filter.setValue(1 - grade.highlights * 0.65, forKey: "inputHighlightAmount")
            filter.setValue(max(0, grade.shadows), forKey: "inputShadowAmount")
            result = filter.outputImage ?? result
        }
        if grade.warmth != 0, let filter = CIFilter(name: "CITemperatureAndTint") {
            filter.setValue(result, forKey: kCIInputImageKey)
            filter.setValue(CIVector(x: 6500, y: 0), forKey: "inputNeutral")
            filter.setValue(CIVector(x: 6500 - grade.warmth * 2200, y: 0), forKey: "inputTargetNeutral")
            result = filter.outputImage ?? result
        }
        if grade.sharp > 0, let filter = CIFilter(name: "CISharpenLuminance") {
            filter.setValue(result, forKey: kCIInputImageKey)
            filter.setValue(grade.sharp * 1.4, forKey: kCIInputSharpnessKey)
            result = filter.outputImage ?? result
        }
        if grade.vignette > 0, let filter = CIFilter(name: "CIVignette") {
            filter.setValue(result, forKey: kCIInputImageKey)
            filter.setValue(1.6, forKey: kCIInputRadiusKey)
            filter.setValue(grade.vignette * 1.8, forKey: kCIInputIntensityKey)
            result = filter.outputImage ?? result
        }
        if grade.grain > 0.01 {
            result = grain(result, amount: grade.grain)
        }
        return result
    }

    private static func grain(_ image: CIImage, amount: Double) -> CIImage {
        guard let random = CIFilter(name: "CIRandomGenerator")?.outputImage else { return image }
        let noise = random.cropped(to: image.extent)
        guard let mono = CIFilter(name: "CIColorControls") else { return image }
        mono.setValue(noise, forKey: kCIInputImageKey)
        mono.setValue(0, forKey: kCIInputSaturationKey)
        mono.setValue(0, forKey: kCIInputBrightnessKey)
        mono.setValue(1.1, forKey: kCIInputContrastKey)
        guard let gray = mono.outputImage, let soft = CIFilter(name: "CISoftLightBlendMode") else { return image }
        soft.setValue(gray, forKey: kCIInputImageKey)
        soft.setValue(image, forKey: kCIInputBackgroundImageKey)
        guard let mixed = soft.outputImage, let dissolve = CIFilter(name: "CIDissolveTransition") else { return image }
        dissolve.setValue(image, forKey: kCIInputImageKey)
        dissolve.setValue(mixed, forKey: kCIInputTargetImageKey)
        dissolve.setValue(min(1, amount * 0.85), forKey: kCIInputTimeKey)
        return dissolve.outputImage?.cropped(to: image.extent) ?? image
    }

    static func preview(image: CIImage, grade: PhotoGrade) -> UIImage? {
        let graded = apply(fitted(image, maxSide: 540), grade)
        guard let cg = context.createCGImage(graded, from: graded.extent) else { return nil }
        return UIImage(cgImage: cg)
    }

    static func jpeg(from data: Data, grade: PhotoGrade) -> Data? {
        guard let image = CIImage(data: data) else { return nil }
        return jpegData(apply(image, grade))
    }

    static func jpeg(from image: CIImage, grade: PhotoGrade) -> Data? {
        jpegData(apply(image, grade))
    }

    private static func fitted(_ image: CIImage, maxSide: CGFloat) -> CIImage {
        let longest = max(image.extent.width, image.extent.height)
        guard longest > maxSide, longest > 0 else { return image }
        let scale = maxSide / longest
        return image.transformed(by: CGAffineTransform(scaleX: scale, y: scale))
    }

    private static func jpegData(_ image: CIImage) -> Data? {
        guard let colorSpace = CGColorSpace(name: CGColorSpace.sRGB) else { return nil }
        return context.jpegRepresentation(
            of: image,
            colorSpace: colorSpace,
            options: [kCGImageDestinationLossyCompressionQuality as CIImageRepresentationOption: 0.92]
        )
    }
}
