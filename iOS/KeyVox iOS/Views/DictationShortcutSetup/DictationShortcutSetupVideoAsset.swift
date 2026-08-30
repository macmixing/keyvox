import CoreGraphics

struct DictationShortcutSetupVideoAsset {
    let name: String
    let pixelWidth: CGFloat
    let pixelHeight: CGFloat

    var aspectRatio: CGFloat {
        pixelWidth / pixelHeight
    }

    func height(forWidth width: CGFloat) -> CGFloat {
        width * pixelHeight / pixelWidth
    }
}
