import SwiftUI

struct KeyVoxSpeakUnlockScene: View {
    let isVisible: Bool

    var body: some View {
        VStack(spacing: 24) {
            Spacer(minLength: 24)

            LogoBarView(size: 96)
                .opacity(isVisible ? 1 : 0.72)

            VStack(spacing: 8) {
                Text("KeyVox Speak")
                    .font(.appFont(30, variant: .medium))
                    .foregroundStyle(.white)

                Text("Unlock flow placeholder")
                    .font(.appFont(18, variant: .light))
                    .foregroundStyle(.white.opacity(0.72))
            }

            Spacer(minLength: 24)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.horizontal, 24)
    }
}

#Preview {
    KeyVoxSpeakUnlockScene(isVisible: true)
        .background(AppTheme.screenBackground)
}
