import UIKit

/// Draws an emoji of two people with one or both of them in gray, as the system emoji keyboard's
/// two-person skin-tone picker shows a person whose tone is not chosen (measured gray: 142, 142,
/// 147, light and dark). The gray covers what changes with that person's tone, found by drawing
/// the emoji with the person in two tones; what never changes with the tone, such as clothes,
/// stays in color, where the system picker grays the whole person.
enum KeyboardEmojiSilhouetteRenderer {
    static let gray = UIColor(red: 142 / 255, green: 142 / 255, blue: 147 / 255, alpha: 1)
    /// How far apart two drawings' colors must be, summed over red, green, and blue out of 255
    /// each, for a pixel to count as changing with the tone.
    private static let changeThreshold = 24

    /// `version` drawn in `font`, with the pixels that differ from each of `comparisons`, versions
    /// with only a grayed person's tone changed, in gray.
    static func image(of version: String, graying comparisons: [String], font: UIFont, scale: CGFloat) -> UIImage? {
        let attributes: [NSAttributedString.Key: Any] = [.font: font]
        let size = (version as NSString).size(withAttributes: attributes)
        let width = Int((size.width * scale).rounded(.up))
        let height = Int((size.height * scale).rounded(.up))
        guard width > 0, height > 0, var base = pixels(of: version, attributes: attributes, width: width, height: height, scale: scale) else {
            return nil
        }
        let grayComponents = gray.rgbaBytes
        let original = base
        for comparison in comparisons {
            guard let other = pixels(of: comparison, attributes: attributes, width: width, height: height, scale: scale) else {
                continue
            }
            for pixel in stride(from: 0, to: base.count, by: 4) where changes(original, other, at: pixel) {
                let alpha = Int(base[pixel + 3])
                // Premultiplied, so the gray keeps the drawing's edges.
                for channel in 0..<3 {
                    base[pixel + channel] = UInt8(Int(grayComponents[channel]) * alpha / 255)
                }
            }
        }
        guard let image = makeImage(base, width: width, height: height) else { return nil }
        return UIImage(cgImage: image, scale: scale, orientation: .up)
    }

    private static func changes(_ base: [UInt8], _ other: [UInt8], at pixel: Int) -> Bool {
        guard base[pixel + 3] > 0 else { return false }
        let difference = (0..<3).reduce(0) { $0 + abs(Int(base[pixel + $1]) - Int(other[pixel + $1])) }
        return difference > changeThreshold
    }

    private static func pixels(
        of text: String,
        attributes: [NSAttributedString.Key: Any],
        width: Int,
        height: Int,
        scale: CGFloat
    ) -> [UInt8]? {
        var data = [UInt8](repeating: 0, count: width * height * 4)
        let drawn = data.withUnsafeMutableBytes { buffer -> Bool in
            guard let context = CGContext(
                data: buffer.baseAddress,
                width: width,
                height: height,
                bitsPerComponent: 8,
                bytesPerRow: width * 4,
                space: CGColorSpaceCreateDeviceRGB(),
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
            ) else {
                return false
            }
            // UIKit draws top down.
            context.translateBy(x: 0, y: CGFloat(height))
            context.scaleBy(x: scale, y: -scale)
            UIGraphicsPushContext(context)
            (text as NSString).draw(at: .zero, withAttributes: attributes)
            UIGraphicsPopContext()
            return true
        }
        return drawn ? data : nil
    }

    private static func makeImage(_ data: [UInt8], width: Int, height: Int) -> CGImage? {
        guard let provider = CGDataProvider(data: Data(data) as CFData) else { return nil }
        return CGImage(
            width: width,
            height: height,
            bitsPerComponent: 8,
            bitsPerPixel: 32,
            bytesPerRow: width * 4,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue),
            provider: provider,
            decode: nil,
            shouldInterpolate: true,
            intent: .defaultIntent
        )
    }
}

private extension UIColor {
    /// The color's red, green, blue, and alpha, each out of 255.
    var rgbaBytes: [UInt8] {
        var red: CGFloat = 0, green: CGFloat = 0, blue: CGFloat = 0, alpha: CGFloat = 0
        getRed(&red, green: &green, blue: &blue, alpha: &alpha)
        return [red, green, blue, alpha].map { UInt8(($0 * 255).rounded()) }
    }
}
