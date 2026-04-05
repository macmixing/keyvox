import SwiftUI

struct KeyVoxSpeakSceneBView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Listen Anywhere")
                .font(.appFont(26))
                .foregroundStyle(.white)

            Text("Speak copied text from the app and jump back into replay whenever you want to hear it again.")
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
