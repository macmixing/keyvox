import UIKit

/// One emoji drawn by the shared `KeyboardEmojiGlyphRenderer`, centered in this view where a
/// centered label would draw it, optionally with a soft glow around it.
final class KeyboardEmojiGlyphView: UIView {
    private let glyphLayer = CALayer()
    /// Shows the emoji as text only when the renderer can't draw it.
    private let fallbackLabel = UILabel()
    private var emoji: String?
    private var pointSize: CGFloat = 0
    private var glowColor: UIColor?
    private var glowRadius: CGFloat = 0

    override init(frame: CGRect) {
        super.init(frame: frame)
        isUserInteractionEnabled = false
        glyphLayer.actions = ["contents": NSNull(), "bounds": NSNull(), "position": NSNull()]
        layer.addSublayer(glyphLayer)
        fallbackLabel.textAlignment = .center
        addSubview(fallbackLabel)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    /// Shows `emoji` at `pointSize`, or nothing when nil.
    func show(_ emoji: String?, pointSize: CGFloat) {
        self.emoji = emoji
        self.pointSize = pointSize
        setNeedsLayout()
    }

    /// A soft halo of `color` around the emoji, or none when nil, blurred by `radius` as text's
    /// shadow of that blur radius is.
    func setGlow(_ color: UIColor?, radius: CGFloat) {
        glowColor = color
        glowRadius = radius
        setNeedsLayout()
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        let scale = max(1, traitCollection.displayScale)
        let glyph = emoji.flatMap { KeyboardEmojiGlyphRenderer.shared.glyph(for: $0, size: pointSize, scale: scale) }
        fallbackLabel.text = glyph == nil ? emoji : nil
        fallbackLabel.font = .systemFont(ofSize: max(1, pointSize))
        fallbackLabel.frame = bounds
        glyphLayer.contentsScale = scale
        guard let glyph else {
            glyphLayer.contents = nil
            return
        }
        var rect = glyph.rect
        var image = glyph.image
        if let glowColor, let glowing = Self.glowing(glyph, color: glowColor, radius: glowRadius, scale: scale) {
            image = glowing.image
            rect = rect.insetBy(dx: -glowing.padding, dy: -glowing.padding)
        }
        glyphLayer.contents = image
        // Where a centered label would draw it, on whole pixels.
        let x = ((bounds.midX + rect.minX) * scale).rounded() / scale
        let y = ((bounds.midY + rect.minY) * scale).rounded() / scale
        glyphLayer.frame = CGRect(x: x, y: y, width: rect.width, height: rect.height)
    }

    /// The emoji's picture drawn with a shadow of `color` and blur `radius`, the way text draws its
    /// shadow, in a bitmap padded on every side by `padding` points so the glow fits.
    private static func glowing(
        _ glyph: KeyboardEmojiGlyph,
        color: UIColor,
        radius: CGFloat,
        scale: CGFloat
    ) -> (image: CGImage, padding: CGFloat)? {
        let padding = (radius * 2).rounded(.up)
        let format = UIGraphicsImageRendererFormat()
        format.scale = scale
        let size = CGSize(width: glyph.rect.width + padding * 2, height: glyph.rect.height + padding * 2)
        let image = UIGraphicsImageRenderer(size: size, format: format).image { context in
            context.cgContext.setShadow(offset: .zero, blur: radius, color: color.cgColor)
            UIImage(cgImage: glyph.image, scale: scale, orientation: .up)
                .draw(in: CGRect(x: padding, y: padding, width: glyph.rect.width, height: glyph.rect.height))
        }
        return image.cgImage.map { ($0, padding) }
    }
}
