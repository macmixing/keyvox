import SwiftUI

struct KeyVoxSpeakSceneAView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("KeyVox Speak")
                .font(.appFont(26))
                .foregroundStyle(.white)

            Text("A new copied-text playback feature is now available in KeyVox.")
                .font(.appFont(16, variant: .light))
                .foregroundStyle(.white.opacity(0.78))

            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .padding(.horizontal, 24)
        .padding(.top, 24)
        .padding(.bottom, 24)
    }
}
