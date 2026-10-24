import SwiftUI

/// The spacing, text size, and video sizing of the return-to-app screens: the usual layout, and a
/// tighter one that gives the video more of a squat screen.
struct ReturnToHostLayoutMetrics {
    static let videoSize: CGFloat = 350

    let spacing: CGFloat
    let textScale: CGFloat
    let isVideoFixed: Bool
    /// Whether flexible space separates the headline from the video.
    let separatesHeadline: Bool
    /// How far the video is nudged up from where the stack places it.
    let videoOffset: CGFloat
    /// How far the text under the video is nudged up toward it.
    let bodyOffset: CGFloat
    /// Whether text that changes as the screen's state changes keeps room for every state's text,
    /// so choosing between layouts does not change with the state.
    let reservesStateText: Bool

    /// The usual layout: the video at full size wherever it fits, shrinking only on screens too
    /// short for the text around it.
    static func usual(spacing: CGFloat) -> ReturnToHostLayoutMetrics {
        ReturnToHostLayoutMetrics(
            spacing: spacing,
            textScale: 1,
            isVideoFixed: false,
            separatesHeadline: true,
            videoOffset: -30,
            bodyOffset: -5,
            reservesStateText: false
        )
    }

    /// The usual layout with the video held at full size, which a squat screen keeps wherever it
    /// fits.
    static func usualAtFullSize(spacing: CGFloat) -> ReturnToHostLayoutMetrics {
        ReturnToHostLayoutMetrics(
            spacing: spacing,
            textScale: 1,
            isVideoFixed: true,
            separatesHeadline: true,
            videoOffset: -30,
            bodyOffset: -5,
            reservesStateText: true
        )
    }

    /// Closer sections and smaller text, leaving the video more of a squat screen; the video sits
    /// the same spacing from the text above and below it.
    static let compact = ReturnToHostLayoutMetrics(
        spacing: 14,
        textScale: 0.85,
        isVideoFixed: false,
        separatesHeadline: false,
        videoOffset: 0,
        bodyOffset: 0,
        reservesStateText: true
    )

    /// Sizes the video's space: held at full size, or full size wherever it fits and shrinking
    /// only on screens too short for the text around it.
    @ViewBuilder
    func videoFrame<Content: View>(_ content: Content) -> some View {
        if isVideoFixed {
            content.frame(width: Self.videoSize, height: Self.videoSize)
        } else {
            content
                .frame(maxWidth: Self.videoSize, maxHeight: Self.videoSize)
                .aspectRatio(1, contentMode: .fit)
                .layoutPriority(1)
        }
    }
}
