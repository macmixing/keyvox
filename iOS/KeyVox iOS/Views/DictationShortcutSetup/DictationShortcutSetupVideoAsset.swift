import CoreGraphics

struct DictationShortcutSetupVideoAsset {
    let name: String
    let pixelWidth: CGFloat
    let pixelHeight: CGFloat
    let viewportPixelWidth: CGFloat

    init(
        name: String,
        pixelWidth: CGFloat,
        pixelHeight: CGFloat,
        viewportPixelWidth: CGFloat? = nil
    ) {
        self.name = name
        self.pixelWidth = pixelWidth
        self.pixelHeight = pixelHeight
        self.viewportPixelWidth = viewportPixelWidth ?? pixelWidth
    }

    var aspectRatio: CGFloat {
        pixelWidth / pixelHeight
    }

    func height(forWidth width: CGFloat) -> CGFloat {
        width * pixelHeight / pixelWidth
    }

    func width(forViewportWidth viewportWidth: CGFloat) -> CGFloat {
        viewportWidth * pixelWidth / viewportPixelWidth
    }
}
