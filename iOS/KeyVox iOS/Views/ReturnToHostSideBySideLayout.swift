import SwiftUI

/// The text on the left and the video on the right, the gap between the text and the video's
/// drawing centered on the fold, and anything below them centered on the fold, or under the video
/// while the fold is active.
struct ReturnToHostSideBySideLayout<Text: View, Video: View, Footer: View>: View {
    private let metrics: ReturnToHostLayoutMetrics
    private let text: Text
    private let video: Video
    private let footer: Footer

    init(
        metrics: ReturnToHostLayoutMetrics,
        @ViewBuilder text: () -> Text,
        @ViewBuilder video: () -> Video,
        @ViewBuilder footer: () -> Footer = { EmptyView() }
    ) {
        self.metrics = metrics
        self.text = text()
        self.video = video()
        self.footer = footer()
    }

    var body: some View {
        VStack(alignment: .footerCenter, spacing: 32) {
            HStack(spacing: 0) {
                text
                    .frame(width: max(metrics.foldX - metrics.spacing / 2, 0), alignment: .trailing)

                // Shifted toward the fold by the artwork's empty edge, so the drawing starts
                // the gap's width from the text.
                video
                    .visualEffect { content, proxy in
                        content.offset(x: -proxy.size.width * ReturnToHostLayoutMetrics.videoArtworkInsetFraction)
                    }
                    .alignmentGuide(.footerCenter) { dimensions in
                        dimensions[HorizontalAlignment.center]
                            - dimensions.width * ReturnToHostLayoutMetrics.videoArtworkInsetFraction
                    }
                    .padding(.leading, metrics.spacing)
            }
            .alignmentGuide(.footerCenter) { dimensions in
                metrics.isFoldActive ? dimensions[.footerCenter] : metrics.foldX
            }

            footer
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .animation(.easeInOut(duration: 0.35), value: metrics.isFoldActive)
    }
}

private extension HorizontalAlignment {
    private enum FooterCenter: AlignmentID {
        static func defaultValue(in dimensions: ViewDimensions) -> CGFloat {
            dimensions[HorizontalAlignment.center]
        }
    }

    /// Where the footer centers: the fold, or the middle of the video's drawing while the fold is
    /// active.
    static let footerCenter = HorizontalAlignment(FooterCenter.self)
}
