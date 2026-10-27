import SwiftUI

struct DictationShortcutSetupPageView: View {
    private enum Layout {
        static let videoHorizontalInset: CGFloat = 5
        static let videoTopInset: CGFloat = -8
    }

    let page: DictationShortcutSetupPage
    let isActive: Bool
    let animatesShortcutIntroEntrance: Bool

    init(
        page: DictationShortcutSetupPage,
        isActive: Bool = true,
        animatesShortcutIntroEntrance: Bool = true
    ) {
        self.page = page
        self.isActive = isActive
        self.animatesShortcutIntroEntrance = animatesShortcutIntroEntrance
    }

    var body: some View {
        if page == .shortcutIntro, let videoAsset = page.videoAsset {
            ShortcutIntroView(
                videoAsset: videoAsset,
                isActive: isActive,
                animatesEntrance: animatesShortcutIntroEntrance
            )
        } else {
            standardPage
        }
    }

    private var standardPage: some View {
        ZStack {
            if let videoAsset = page.videoAsset {
                GeometryReader { geometry in
                    let viewportWidth = fittedViewportWidth(for: videoAsset, in: geometry.size)
                    let videoWidth = videoAsset.width(
                        forViewportWidth: viewportWidth
                    )
                    let videoHeight = videoAsset.height(forWidth: videoWidth)

                    ZStack {
                        DictationShortcutSetupVideoView(
                            asset: videoAsset,
                            isActive: isActive
                        )
                        .frame(width: videoWidth, height: videoHeight)
                    }
                    .frame(width: geometry.size.width, height: videoHeight)
                    .clipped()
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel(Text(page.videoAccessibilityLabel ?? ""))
                    .accessibilityHidden(page.videoAccessibilityLabel == nil)
                    .position(
                        x: geometry.size.width / 2,
                        y: Layout.videoTopInset + (videoHeight / 2)
                    )
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    /// The page's width less the video's insets. On iPad the video is also kept no taller than
    /// the page, so the whole recording stays in view on wide windows.
    private func fittedViewportWidth(
        for videoAsset: DictationShortcutSetupVideoAsset,
        in pageSize: CGSize
    ) -> CGFloat {
        let widthLimit = max(pageSize.width - (Layout.videoHorizontalInset * 2), 0)
        guard AppDevice.isPad else { return widthLimit }

        let heightLimit = videoAsset.viewportWidth(forHeight: pageSize.height - Layout.videoTopInset)
        return min(widthLimit, max(heightLimit, 0))
    }
}
