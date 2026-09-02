import SwiftUI

struct DictationShortcutSetupPageView: View {
    private enum Layout {
        static let videoHorizontalInset: CGFloat = 5
        static let videoTopInset: CGFloat = -60
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
                    let viewportWidth = max(
                        geometry.size.width - (Layout.videoHorizontalInset * 2),
                        0
                    )
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
}
