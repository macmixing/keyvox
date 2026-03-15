import SwiftUI

struct OnboardingWelcomeScreen: View {
    let onContinue: () -> Void

    var body: some View {
        OnboardingScreenScaffold(
            title: "Welcome to KeyVox",
            actionTitle: "Let's go",
            action: onContinue
        ) {
            Text("We’ll get the core pieces ready, then you can jump straight in.")
                .font(.appFont(16, variant: .light))
                .foregroundStyle(.secondary)
        }
    }
}
