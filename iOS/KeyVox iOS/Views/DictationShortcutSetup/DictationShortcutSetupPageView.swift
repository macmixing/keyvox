import SwiftUI

struct DictationShortcutSetupPageView: View {
    private enum Layout {
        static let videoHorizontalInset: CGFloat = 5
        static let videoTopInset: CGFloat = -60
        static let placeholderTitleTopPadding: CGFloat = 36
    }

    let page: DictationShortcutSetupPage
    let isActive: Bool

    init(
        page: DictationShortcutSetupPage,
        isActive: Bool = true
    ) {
        self.page = page
        self.isActive = isActive
    }

    var body: some View {
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
                    .position(
                        x: geometry.size.width / 2,
                        y: Layout.videoTopInset + (videoHeight / 2)
                    )
                }
            } else if page.includesVideoPlaceholder {
                DictationShortcutSetupVideoPlaceholder(page: page)
                    .frame(maxWidth: 350)
                    .padding(.horizontal, AppTheme.screenPadding)
            }

            if page.videoAsset == nil {
                Text("Page \(page.rawValue)")
                    .font(.appFont(34, variant: .medium))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                    .padding(.top, Layout.placeholderTitleTopPadding)
                    .padding(.horizontal, AppTheme.screenPadding)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
