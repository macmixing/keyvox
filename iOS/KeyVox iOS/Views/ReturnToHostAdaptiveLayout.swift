import SwiftUI

/// Lays out a return-to-app screen in the usual layout, except on a squat screen, which keeps the
/// usual layout only while the video fits at full size and otherwise takes the tighter one.
struct ReturnToHostAdaptiveLayout<Content: View>: View {
    /// Height over width of the whole display below which it counts as squat: the closed iPhone
    /// Duo's display (about 1.45) is under it, and every other iPhone display is at least 1.77.
    static var squatAspectRatio: CGFloat { 1.6 }

    private let spacing: CGFloat
    private let content: (ReturnToHostLayoutMetrics) -> Content

    init(spacing: CGFloat, @ViewBuilder content: @escaping (ReturnToHostLayoutMetrics) -> Content) {
        self.spacing = spacing
        self.content = content
    }

    var body: some View {
        GeometryReader { proxy in
            Group {
                if Self.isSquat(Self.displaySize(proxy)) {
                    ViewThatFits(in: .vertical) {
                        content(.usualAtFullSize(spacing: spacing))
                        // Text held at the standard size, which the tighter layout is laid out for.
                        content(.compact)
                            .dynamicTypeSize(.large)
                    }
                } else {
                    content(.usual(spacing: spacing))
                }
            }
            .frame(width: proxy.size.width, height: proxy.size.height)
        }
    }

    /// The whole display: the layout's space plus the safe area around it, which the system's
    /// status bar and camera take differently on different displays.
    private static func displaySize(_ proxy: GeometryProxy) -> CGSize {
        let insets = proxy.safeAreaInsets
        return CGSize(
            width: proxy.size.width + insets.leading + insets.trailing,
            height: proxy.size.height + insets.top + insets.bottom
        )
    }

    private static func isSquat(_ size: CGSize) -> Bool {
        size.width > 0 && size.height / size.width < squatAspectRatio
    }
}
