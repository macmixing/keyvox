import SwiftUI

struct OnboardingKeyboardTourSceneCView: View {
    var body: some View {
        VStack(spacing: 16) {
            Text("C")
                .font(.system(size: 160, weight: .heavy))
                .foregroundStyle(.primary)

            Text("You did it. You can finish now.")
                .font(.appFont(20, variant: .light))
                .foregroundStyle(.primary)
                .multilineTextAlignment(.center)
        }
    }
}
