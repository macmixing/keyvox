import CoreGraphics

enum OverlayPillMetrics {
    static let width: CGFloat = 124
    static let height: CGFloat = 44
    static let contentSpacing: CGFloat = 8
    static let paragraphContentSpacing = contentSpacing / 2 - 1

    static var panelSize: CGSize {
        CGSize(
            width: width
                + (OverlayPresentationMetrics.contentPadding * 2)
                + (OverlayPresentationMetrics.shadowBleedPadding * 2),
            height: height
                + (OverlayPresentationMetrics.contentPadding * 2)
                + (OverlayPresentationMetrics.shadowBleedPadding * 2)
        )
    }
}
