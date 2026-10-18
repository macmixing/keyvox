import UIKit

/// Draws an emoji of two people with one or both of them as a flat gray silhouette, as the system
/// emoji keyboard's two-person skin-tone picker shows a person whose tone is not chosen (measured
/// gray: 142, 142, 147, light and dark). A person's own pixels are the ones that change with their
/// tone, found by drawing the emoji with that person in another tone; every other pixel, such as
/// outlines and clothes, belongs to whichever person's own pixels are nearest, so the whole of a
/// grayed person turns gray. In an emoji whose people a heart joins, the heart keeps its color.
enum KeyboardEmojiSilhouetteRenderer {
    static let gray = UIColor(red: 142 / 255, green: 142 / 255, blue: 147 / 255, alpha: 1)
    /// How far apart two drawings' colors must be, summed over red, green, and blue out of 255
    /// each, for a pixel to count as changing with the tone.
    private static let changeThreshold = 24
    /// The heart a couple's emoji joins its people with.
    private static let heartScalar: Unicode.Scalar = "\u{2764}"
    /// The heart's colors, measured on the iOS Simulator across every emoji that holds one: its
    /// pink, its shine, and its edge all have at least this much red and blue, out of 255, and more
    /// blue than green. The heart is drawn pink, not in the red of the heart emoji on its own.
    private static let heartMinimumRed = 192
    private static let heartMinimumBlue = 128
    /// The heart's most common color, measured the same way, which a run of heart-colored pixels
    /// must hold to be the heart.
    private static let heartMainColor = (red: 248, green: 72, blue: 184)

    /// Whose a pixel is.
    private enum Owner {
        case unassigned
        case grayed
        case kept
    }

    /// `version` drawn in `font`, with the grayed people in gray.
    /// - Parameters:
    ///   - grayedComparisons: Versions with only a grayed person's tone changed.
    ///   - keptComparisons: Versions with only the person kept in color's tone changed; none when
    ///     both people are grayed.
    static func image(
        of version: String,
        graying grayedComparisons: [String],
        keeping keptComparisons: [String],
        font: UIFont,
        scale: CGFloat
    ) -> UIImage? {
        let attributes: [NSAttributedString.Key: Any] = [.font: font]
        let size = (version as NSString).size(withAttributes: attributes)
        let width = Int((size.width * scale).rounded(.up))
        let height = Int((size.height * scale).rounded(.up))
        guard width > 0, height > 0, var base = pixels(of: version, attributes: attributes, width: width, height: height, scale: scale) else {
            return nil
        }
        let changedWithGrayed = changedPixels(of: base, comparedWith: grayedComparisons, attributes: attributes, width: width, height: height, scale: scale)
        if changedWithGrayed.contains(true) {
            let changedWithKept = changedPixels(of: base, comparedWith: keptComparisons, attributes: attributes, width: width, height: height, scale: scale)
            let drawn = (0..<(width * height)).map { base[$0 * 4 + 3] > 0 }
            let owners = nearestOwners(grayed: changedWithGrayed, kept: changedWithKept, drawn: drawn, width: width, height: height)
            let heart = version.unicodeScalars.contains(heartScalar)
                ? heartPixels(in: base, width: width, height: height)
                : [Bool](repeating: false, count: width * height)
            let grayComponents = gray.rgbaBytes
            for index in owners.indices where owners[index] == .grayed && !heart[index] {
                let pixel = index * 4
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

    /// Whether each pixel of `base` differs from the same pixel of any of `comparisons`.
    private static func changedPixels(
        of base: [UInt8],
        comparedWith comparisons: [String],
        attributes: [NSAttributedString.Key: Any],
        width: Int,
        height: Int,
        scale: CGFloat
    ) -> [Bool] {
        var changed = [Bool](repeating: false, count: width * height)
        for comparison in comparisons {
            guard let other = pixels(of: comparison, attributes: attributes, width: width, height: height, scale: scale) else {
                continue
            }
            for index in changed.indices where changes(base, other, at: index * 4) {
                changed[index] = true
            }
        }
        return changed
    }

    /// The pixels of the heart in `base`: runs of pixels in the heart's colors that hold its most
    /// common color, so its shine and edge come with it and stray pixels of the same colors do not.
    private static func heartPixels(in base: [UInt8], width: Int, height: Int) -> [Bool] {
        let count = width * height
        var heart = [Bool](repeating: false, count: count)
        let inHeartColors = (0..<count).map { isHeartColored(base, at: $0 * 4) }
        var visited = [Bool](repeating: false, count: count)
        for start in 0..<count where inHeartColors[start] && !visited[start] {
            var run = [start]
            visited[start] = true
            var head = 0
            var holdsMainColor = false
            func visit(_ x: Int, _ y: Int) {
                guard x >= 0, x < width, y >= 0, y < height else { return }
                let neighbor = y * width + x
                guard inHeartColors[neighbor], !visited[neighbor] else { return }
                visited[neighbor] = true
                run.append(neighbor)
            }
            while head < run.count {
                let index = run[head]
                head += 1
                if isHeartMainColor(base, at: index * 4) {
                    holdsMainColor = true
                }
                let x = index % width
                let y = index / width
                visit(x - 1, y)
                visit(x + 1, y)
                visit(x, y - 1)
                visit(x, y + 1)
            }
            if holdsMainColor {
                for index in run {
                    heart[index] = true
                }
            }
        }
        return heart
    }

    /// Whether the pixel at `pixel` is one of the heart's colors.
    private static func isHeartColored(_ data: [UInt8], at pixel: Int) -> Bool {
        guard let (red, green, blue) = unpremultipliedColor(data, at: pixel) else { return false }
        return red >= heartMinimumRed && blue >= heartMinimumBlue && blue > green
    }

    /// Whether the pixel at `pixel` is the heart's most common color.
    private static func isHeartMainColor(_ data: [UInt8], at pixel: Int) -> Bool {
        guard let (red, green, blue) = unpremultipliedColor(data, at: pixel) else { return false }
        let difference = abs(red - heartMainColor.red) + abs(green - heartMainColor.green) + abs(blue - heartMainColor.blue)
        return difference <= changeThreshold
    }

    /// The pixel's red, green, and blue without its transparency, or nil for a clear pixel.
    private static func unpremultipliedColor(_ data: [UInt8], at pixel: Int) -> (Int, Int, Int)? {
        let alpha = Int(data[pixel + 3])
        guard alpha > 0 else { return nil }
        let channels = (0..<3).map { min(255, Int(data[pixel + $0]) * 255 / alpha) }
        return (channels[0], channels[1], channels[2])
    }

    /// Each pixel's owner: a pixel that changes with a person's tone is that person's, and every
    /// other drawn pixel is the person's whose own pixels are fewest steps away through the
    /// drawing, so the gap between the people keeps one person's clothes from going to the other.
    /// What the drawing does not connect to either person goes to the nearest one across the gap.
    /// With no kept pixels, every pixel is grayed.
    private static func nearestOwners(grayed: [Bool], kept: [Bool], drawn: [Bool], width: Int, height: Int) -> [Owner] {
        var owners = [Owner](repeating: .unassigned, count: grayed.count)
        var seeds: [Int] = []
        for index in grayed.indices where grayed[index] {
            owners[index] = .grayed
            seeds.append(index)
        }
        for index in kept.indices where kept[index] && owners[index] == .unassigned {
            owners[index] = .kept
            seeds.append(index)
        }
        spreadOwnership(&owners, from: seeds, width: width, height: height) { drawn[$0] }
        let owned = owners.indices.filter { owners[$0] != .unassigned }
        spreadOwnership(&owners, from: owned, width: width, height: height) { _ in true }
        return owners
    }

    /// Spreads the owners of `seeds` to the unowned pixels `canEnter` allows, each pixel taking the
    /// owner that reaches it in the fewest steps.
    private static func spreadOwnership(
        _ owners: inout [Owner],
        from seeds: [Int],
        width: Int,
        height: Int,
        canEnter: (Int) -> Bool
    ) {
        var queue = seeds
        var head = 0
        func spread(_ owner: Owner, to x: Int, _ y: Int) {
            guard x >= 0, x < width, y >= 0, y < height else { return }
            let neighbor = y * width + x
            guard owners[neighbor] == .unassigned, canEnter(neighbor) else { return }
            owners[neighbor] = owner
            queue.append(neighbor)
        }
        while head < queue.count {
            let index = queue[head]
            head += 1
            let x = index % width
            let y = index / width
            spread(owners[index], to: x - 1, y)
            spread(owners[index], to: x + 1, y)
            spread(owners[index], to: x, y - 1)
            spread(owners[index], to: x, y + 1)
        }
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
