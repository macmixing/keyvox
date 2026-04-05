import SwiftUI

struct KeyVoxSpeakSceneAView: View {
    private static let demoResourceName = "keyvox-speak-demo"

    @EnvironmentObject private var ttsPreviewPlayer: TTSPreviewPlayer

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("KeyVox Speak")
                .font(.appFont(26))
                .foregroundStyle(.white)

            Text("A new copied-text playback feature is now available in KeyVox.")
                .font(.appFont(16, variant: .light))
                .foregroundStyle(.white.opacity(0.78))

            keyVoxSpeakDemoButton

            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .padding(.horizontal, 24)
        .padding(.top, 24)
        .padding(.bottom, 24)
    }

    private var keyVoxSpeakDemoButton: some View {
        let isActive = ttsPreviewPlayer.isActive(resourceName: Self.demoResourceName)
        let isPlaying = isActive && ttsPreviewPlayer.isPlaying
        let symbolName = isPlaying ? "pause.circle" : "play.circle"
        let canPlayPreview = ttsPreviewPlayer.hasPreview(resourceName: Self.demoResourceName)

        return Button {
            ttsPreviewPlayer.togglePlayback(resourceName: Self.demoResourceName)
        } label: {
            Image(systemName: symbolName)
                .font(.system(size: 26, weight: .regular))
                .foregroundStyle(canPlayPreview ? .yellow : .white.opacity(0.28))
                .frame(width: 32, height: 32)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(!canPlayPreview)
        .accessibilityLabel(isPlaying ? "Pause KeyVox Speak demo" : "Play KeyVox Speak demo")
    }
}
