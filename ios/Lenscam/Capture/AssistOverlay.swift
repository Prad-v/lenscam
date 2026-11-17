import CoreVideo
import UIKit

enum AssistOverlay {
    /// A small zebra and focus-peaking mask. Built only while those overlays are on.
    static func image(buffer: CVPixelBuffer, zebra: Bool, peaking: Bool) -> UIImage? {
        guard zebra || peaking else { return nil }
        CVPixelBufferLockBaseAddress(buffer, .readOnly)
        defer { CVPixelBufferUnlockBaseAddress(buffer, .readOnly) }
        guard let base = CVPixelBufferGetBaseAddressOfPlane(buffer, 0) ?? CVPixelBufferGetBaseAddress(buffer) else {
            return nil
        }
        let width = CVPixelBufferGetWidthOfPlane(buffer, 0)
        let height = CVPixelBufferGetHeightOfPlane(buffer, 0)
        let rowBytes = CVPixelBufferGetBytesPerRowOfPlane(buffer, 0)
        guard width > 8, height > 8, rowBytes > 0 else { return nil }
        let step = 8
        let outW = width / step
        let outH = height / step
        var pixels = [UInt8](repeating: 0, count: outW * outH * 4)
        let source = base.assumingMemoryBound(to: UInt8.self)
        func paint(_ index: Int, red: Int, green: Int, blue: Int, alpha: Int) {
            pixels[index] = UInt8(red * alpha / 255)
            pixels[index + 1] = UInt8(green * alpha / 255)
            pixels[index + 2] = UInt8(blue * alpha / 255)
            pixels[index + 3] = UInt8(alpha)
        }
        for y in 0..<outH {
            let row = y * step * rowBytes
            for x in 0..<outW {
                let value = Int(source[row + x * step])
                let index = (y * outW + x) * 4
                if zebra, value > 230, (x / 2) % 2 == 0 {
                    paint(index, red: 230, green: 180, blue: 40, alpha: 170)
                } else if peaking {
                    let neighbor = Int(source[row + min(width - 1, (x + 1) * step)])
                    if abs(value - neighbor) > 28 {
                        paint(index, red: 225, green: 170, blue: 50, alpha: 190)
                    }
                }
            }
        }
        return pixels.withUnsafeMutableBytes { raw in
            guard let context = CGContext(
                data: raw.baseAddress,
                width: outW,
                height: outH,
                bitsPerComponent: 8,
                bytesPerRow: outW * 4,
                space: CGColorSpaceCreateDeviceRGB(),
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
            ), let cg = context.makeImage() else { return nil }
            return UIImage(cgImage: cg)
        }
    }
}
