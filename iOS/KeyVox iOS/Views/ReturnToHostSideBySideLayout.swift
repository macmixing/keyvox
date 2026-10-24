import SwiftUI

/// The text on the left and the video on the right, the gap between the text and the video's
/// drawing centered on the fold, and anything below them centered on the fold too.
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
        VStack(alignment: .leading, spacing: 32) {
            HStack(spacing: 0) {
                text
                    .frame(width: max(metrics.foldX - metrics.spacing / 2, 0), alignment: .trailing)

                // Shifted toward the fold by the artwork's empty edge, so the drawing starts
                // the gap's width from the text.
                video
                    .visualEffect { content, proxy in
                        content.offset(x: -proxy.size.width * ReturnToHostLayoutMetrics.videoArtworkInsetFraction)
                    }
                    .padding(.leading, metrics.spacing)
            }

            footer
                .alignmentGuide(.leading) { dimensions in
                    dimensions[HorizontalAlignment.center] - metrics.foldX
                }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
    }
}
