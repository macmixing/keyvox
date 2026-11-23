import UIKit

/// Whether an emoji blends into the key it is drawn on: most of its drawing sits too close in
/// color to the key to stand apart from it. The emoji is drawn once and its own pixels are
/// compared with the key's color, so the answer follows the key's colors in any theme and
/// appearance. Colors are compared as the eye sees them, in lightness and hue together, so a
/// bright color on a light key still stands apart. Only a dark key hides an emoji: on a light key,
/// even a white emoji still reads, so no emoji blends into one. Answers are remembered for each
/// emoji and key color.
@MainActor
enum KeyboardEmojiContrastCheck {
    /// The lightness, in CIELAB from 0 (black) to 100 (white), below which a key is dark.
    private static let darkKeyLightness = 50.0
    /// The least difference in color, as the distance between the two colors in CIELAB, a pixel
    /// needs from the key to stand apart from it.
    private static let minimumPixelDifference = 20.0
    /// The share of the emoji's drawing that must lack that contrast for the emoji to blend in.
    private static let blendingShare = 0.5
    /// The size the emoji is drawn at to measure it, in pixels.
    private static let measuringFont = UIFont.systemFont(ofSize: 32)

    private static let answers = NSCache<NSString, NSNumber>()

    /// Whether `emoji` blends into a key whose fill `keyTint` covers `backdrop` behind it.
    static func blendsIn(_ emoji: String, keyTint: UIColor, backdrop: UIColor) -> Bool {
        let key = composite(keyTint, over: backdrop)
        let keyColor = lab(key.red, key.green, key.blue)
        guard keyColor.lightness < darkKeyLightness else { return false }
        let cacheKey = "\(emoji)|\(key.red)|\(key.green)|\(key.blue)" as NSString
        if let answer = answers.object(forKey: cacheKey) {
            return answer.boolValue
        }
        let answer = measureBlending(of: emoji, against: keyColor)
        answers.setObject(NSNumber(value: answer), forKey: cacheKey)
        return answer
    }

    private static func measureBlending(of emoji: String, against keyColor: Lab) -> Bool {
        let attributes: [NSAttributedString.Key: Any] = [.font: measuringFont]
        let size = (emoji as NSString).size(withAttributes: attributes)
        let width = Int(size.width.rounded(.up))
        let height = Int(size.height.rounded(.up))
        guard width > 0, height > 0, let data = pixels(of: emoji, attributes: attributes, width: width, height: height) else {
            return false
        }
        var drawn = 0.0
        var blending = 0.0
        for pixel in stride(from: 0, to: data.count, by: 4) {
            let alpha = Double(data[pixel + 3]) / 255
            guard alpha > 0 else { continue }
            // Premultiplied, so each channel comes back to its own color before it is measured.
            let channels = (0..<3).map { min(1, Double(data[pixel + $0]) / 255 / alpha) }
            let pixelColor = lab(channels[0], channels[1], channels[2])
            drawn += alpha
            if pixelColor.distance(to: keyColor) < minimumPixelDifference {
                blending += alpha
            }
        }
        guard drawn > 0 else { return false }
        return blending / drawn >= blendingShare
    }

    /// `color` laid over `backdrop` at its own transparency, as the key shows it.
    private static func composite(_ color: UIColor, over backdrop: UIColor) -> (red: Double, green: Double, blue: Double) {
        let top = color.rgba
        let bottom = backdrop.rgba
        func mix(_ upper: Double, _ lower: Double) -> Double {
            upper * top.alpha + lower * (1 - top.alpha)
        }
        return (mix(top.red, bottom.red), mix(top.green, bottom.green), mix(top.blue, bottom.blue))
    }

    /// A color in CIELAB, where the distance between two colors follows how different they look.
    private struct Lab {
        let lightness: Double
        let a: Double
        let b: Double

        func distance(to other: Lab) -> Double {
            let lightness = self.lightness - other.lightness
            let a = self.a - other.a
            let b = self.b - other.b
            return (lightness * lightness + a * a + b * b).squareRoot()
        }
    }

    /// An sRGB color in CIELAB, under the D65 white sRGB uses.
    private static func lab(_ red: Double, _ green: Double, _ blue: Double) -> Lab {
        func linear(_ channel: Double) -> Double {
            channel <= 0.04045 ? channel / 12.92 : pow((channel + 0.055) / 1.055, 2.4)
        }
        func curve(_ value: Double) -> Double {
            value > 216 / 24389 ? cbrt(value) : (24389 / 27 * value + 16) / 116
        }
        let (r, g, b) = (linear(red), linear(green), linear(blue))
        let x = curve((0.4124 * r + 0.3576 * g + 0.1805 * b) / 0.95047)
        let y = curve(0.2126 * r + 0.7152 * g + 0.0722 * b)
        let z = curve((0.0193 * r + 0.1192 * g + 0.9505 * b) / 1.08883)
        return Lab(lightness: 116 * y - 16, a: 500 * (x - y), b: 200 * (y - z))
    }

    private static func pixels(
        of text: String,
        attributes: [NSAttributedString.Key: Any],
        width: Int,
        height: Int
    ) -> [UInt8]? {
        var data = [UInt8](repeating: 0, count: width * height * 4)
        let drawn = data.withUnsafeMutableBytes { buffer -> Bool in
            guard let context = CGContext(
                data: buffer.baseAddress,
                width: width,
                height: height,
                bitsPerComponent: 8,
                bytesPerRow: width * 4,
                space: CGColorSpace(name: CGColorSpace.sRGB) ?? CGColorSpaceCreateDeviceRGB(),
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
            ) else {
                return false
            }
            guard let font = attributes[.font] as? UIFont else { return false }
            // Drawn by the shared emoji renderer from the bitmap's top left, as text draws; the
            // bitmap's origin is its bottom left.
            KeyboardEmojiGlyphRenderer.shared.drawText(text, font: font, in: context, topLeft: CGPoint(x: 0, y: CGFloat(height)))
            return true
        }
        return drawn ? data : nil
    }
}

private extension UIColor {
    /// The color's red, green, blue, and alpha in sRGB, each from 0 to 1.
    var rgba: (red: Double, green: Double, blue: Double, alpha: Double) {
        var red: CGFloat = 0, green: CGFloat = 0, blue: CGFloat = 0, alpha: CGFloat = 0
        getRed(&red, green: &green, blue: &blue, alpha: &alpha)
        return (Double(red), Double(green), Double(blue), Double(alpha))
    }
}
