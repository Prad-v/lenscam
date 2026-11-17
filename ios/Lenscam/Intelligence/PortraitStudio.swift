import AVFoundation
import CoreImage
import Foundation
import ImageIO
import UIKit

enum PortraitLight: String, CaseIterable, Identifiable, Sendable {
    case natural
    case studio
    case contour
    case stage
    case stageMono
    case highKey

    var id: String { rawValue }

    var title: String {
        switch self {
        case .natural: "Natural"
        case .studio: "Studio"
        case .contour: "Contour"
        case .stage: "Stage"
        case .stageMono: "Mono"
        case .highKey: "High-Key"
        }
    }
}

enum PortraitStudio {
    private static let context = CIContext(options: [.cacheIntermediates: false])

    static func preview(image: CIImage, disparity: CIImage, aperture: Double, light: PortraitLight, grade: PhotoGrade = PhotoGrade()) -> UIImage? {
        let scaled = fitted(image, maxSide: 540)
        let depth = fitted(disparity, to: scaled.extent)
        guard let blurred = blur(image: scaled, disparity: depth, matte: nil, aperture: aperture) else { return nil }
        let styled = PhotoGradeRender.apply(lighting(blurred, light: light, matte: nil), grade)
        guard let cg = context.createCGImage(styled, from: styled.extent) else { return nil }
        return UIImage(cgImage: cg)
    }

    static func jpeg(from photo: AVCapturePhoto, light: PortraitLight, aperture: Double, grade: PhotoGrade = PhotoGrade()) -> Data? {
        guard let data = photo.fileDataRepresentation(), let source = CIImage(data: data) else { return nil }
        var rendered = source
        if let filter = context.depthBlurEffectFilter(forImageData: data, options: nil) {
            if filter.inputKeys.contains("inputAperture") {
                filter.setValue(aperture, forKey: "inputAperture")
            }
            rendered = filter.outputImage ?? source
        } else if let depth = photo.depthData {
            let disparity = depth.converting(toDepthDataType: kCVPixelFormatType_DisparityFloat32)
            let map = fitted(CIImage(cvPixelBuffer: disparity.depthDataMap), to: source.extent)
            rendered = blur(image: source, disparity: map, matte: nil, aperture: aperture) ?? source
        }
        let matte = photo.portraitEffectsMatte.map { CIImage(cvPixelBuffer: $0.mattingImage) }
        rendered = lighting(rendered, light: light, matte: matte)
        return PhotoGradeRender.jpeg(from: rendered, grade: grade)
    }

    private static func blur(image: CIImage, disparity: CIImage, matte: CIImage?, aperture: Double) -> CIImage? {
        guard let filter = context.depthBlurEffectFilter(
            for: image,
            disparityImage: disparity,
            portraitEffectsMatte: matte,
            orientation: .up,
            options: nil
        ) else { return nil }
        if filter.inputKeys.contains("inputAperture") {
            filter.setValue(aperture, forKey: "inputAperture")
        }
        return filter.outputImage
    }

    private static func lighting(_ image: CIImage, light: PortraitLight, matte: CIImage?) -> CIImage {
        switch light {
        case .natural:
            return image
        case .studio:
            return tone(image, exposure: 0.28, contrast: 1.04, saturation: 0.96)
        case .contour:
            return tone(image, exposure: -0.05, contrast: 1.16, saturation: 0.92)
        case .stage:
            return background(tone(image, exposure: 0.1, contrast: 1.08, saturation: 0.9), matte: matte, color: .black)
        case .stageMono:
            let mono = tone(image, exposure: 0.05, contrast: 1.12, saturation: 0)
            return background(mono, matte: matte, color: .black)
        case .highKey:
            let mono = tone(image, exposure: 0.35, contrast: 1.02, saturation: 0)
            return background(mono, matte: matte, color: .white)
        }
    }

    private static func background(_ image: CIImage, matte: CIImage?, color: CIColor) -> CIImage {
        guard let matte else { return image }
        let scaled = fitted(matte, to: image.extent)
        let plate = CIImage(color: color).cropped(to: image.extent)
        guard let blend = CIFilter(name: "CIBlendWithMask") else { return image }
        blend.setValue(image, forKey: kCIInputImageKey)
        blend.setValue(plate, forKey: kCIInputBackgroundImageKey)
        blend.setValue(scaled, forKey: kCIInputMaskImageKey)
        return blend.outputImage ?? image
    }

    private static func tone(_ image: CIImage, exposure: Double, contrast: Double, saturation: Double) -> CIImage {
        var result = image
        if let filter = CIFilter(name: "CIExposureAdjust") {
            filter.setValue(result, forKey: kCIInputImageKey)
            filter.setValue(exposure, forKey: kCIInputEVKey)
            result = filter.outputImage ?? result
        }
        if let filter = CIFilter(name: "CIColorControls") {
            filter.setValue(result, forKey: kCIInputImageKey)
            filter.setValue(contrast, forKey: kCIInputContrastKey)
            filter.setValue(saturation, forKey: kCIInputSaturationKey)
            result = filter.outputImage ?? result
        }
        return result
    }

    private static func fitted(_ image: CIImage, maxSide: CGFloat) -> CIImage {
        let longest = max(image.extent.width, image.extent.height)
        guard longest > maxSide, longest > 0 else { return image }
        let scale = maxSide / longest
        return image.transformed(by: CGAffineTransform(scaleX: scale, y: scale))
    }

    private static func fitted(_ image: CIImage, to extent: CGRect) -> CIImage {
        guard image.extent.width > 1, image.extent.height > 1 else { return image }
        let scaleX = extent.width / image.extent.width
        let scaleY = extent.height / image.extent.height
        return image.transformed(by: CGAffineTransform(scaleX: scaleX, y: scaleY))
            .transformed(by: CGAffineTransform(translationX: extent.minX, y: extent.minY))
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
