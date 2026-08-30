import SwiftUI

struct DictationShortcutSetupVideoView: View {
    let asset: DictationShortcutSetupVideoAsset
    let isActive: Bool

    var body: some View {
        LoopingVideoPlayer(
            videoName: asset.name,
            isPlaying: isActive,
            isReady: .constant(false)
        )
        .aspectRatio(asset.aspectRatio, contentMode: .fit)
        .accessibilityHidden(true)
    }
}
