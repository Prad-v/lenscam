import CoreImage
import Foundation
import ImageIO
import UIKit

enum ClarityDerivative {
    static func jpeg(from data: Data) -> Data? {
        guard let input = CIImage(data: data) else { return nil }
        guard let filter = CIFilter(name: "CIUnsharpMask") else { return nil }
        filter.setValue(input, forKey: kCIInputImageKey)
        filter.setValue(1.8, forKey: kCIInputRadiusKey)
        filter.setValue(0.55, forKey: kCIInputIntensityKey)
        guard let output = filter.outputImage, let colorSpace = CGColorSpace(name: CGColorSpace.sRGB) else {
            return nil
        }
        let context = CIContext(options: nil)
        return context.jpegRepresentation(
            of: output,
            colorSpace: colorSpace,
            options: [kCGImageDestinationLossyCompressionQuality as CIImageRepresentationOption: 0.92]
        )
    }
}
