import SwiftUI

struct DictationShortcutSetupPageView: View {
    private enum Layout {
        static let videoHorizontalInset: CGFloat = 5
        static let videoTopInset: CGFloat = -60
        static let placeholderTitleTopPadding: CGFloat = 36
    }

    let page: DictationShortcutSetupPage
    let isActive: Bool = true

    var body: some View {
        ZStack {
            if let videoAsset = page.videoAsset {
                GeometryReader { geometry in
                    let videoWidth = max(
                        geometry.size.width - (Layout.videoHorizontalInset * 2),
                        0
                    )
                    let videoHeight = videoAsset.height(forWidth: videoWidth)

                    DictationShortcutSetupVideoView(
                        asset: videoAsset,
                        isActive: isActive
                    )
                        .frame(width: videoWidth, height: videoHeight)
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
