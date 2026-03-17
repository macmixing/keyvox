import SwiftUI

struct OnboardingWelcomeScreen: View {
    let onContinue: () -> Void

    @State private var logoCenterOffset: CGFloat = 0
    @State private var titleOpacity: Double = 0
    @State private var subtitleOpacity: Double = 0
    @State private var buttonOpacity: Double = 0
    @State private var animationTask: Task<Void, Never>?

    var body: some View {
        GeometryReader { geometry in
            AppScrollScreen(scrollDisabled: true) {
                VStack(spacing: 0) {
                    Spacer()
                        .frame(height: 50)

                    OnboardingLogoPopInSequence(
                        size: 100,
                        delay: 0.7,
                        onRevealStarted: runPostPopInSequence
                    )
                        .padding(.bottom, 32)
                        .offset(y: logoCenterOffset)

                    Text("Welcome to KeyVox")
                        .font(.appFont(34, variant: .medium))
                        .foregroundStyle(.white)
                        .multilineTextAlignment(.center)
                        .padding(.bottom, 8)
                        .opacity(titleOpacity)

                    Text("Free Your Voice")
                        .font(.appFont(22, variant: .light))
                        .foregroundStyle(.white.opacity(0.8))
                        .multilineTextAlignment(.center)
                        .opacity(subtitleOpacity)
                }
                .frame(maxWidth: .infinity)
                .padding(.bottom, 112)
            }
            .safeAreaInset(edge: .bottom) {
                VStack(spacing: 0) {
                    AppActionButton(
                        title: "Let's go",
                        style: .primary,
                        fillsWidth: true,
                        fontSize: 25,
                        action: onContinue
                    )
                    .opacity(buttonOpacity)
                    .frame(maxWidth: .infinity)
                }
                .padding(.horizontal, AppTheme.screenPadding)
                .padding(.top, 8)
                .padding(.bottom, 12)
                .background(AppTheme.screenBackground.opacity(0.98))
            }
            .onAppear {
                let screenCenter = geometry.size.height / 2
                let finalLogoY: CGFloat = 50 + 50 + 16 // Spacer + logo half height approx + padding
                logoCenterOffset = screenCenter - finalLogoY
                titleOpacity = 0
                subtitleOpacity = 0
                buttonOpacity = 0
            }
            .onDisappear {
                animationTask?.cancel()
                animationTask = nil
            }
        }
    }

    private func runPostPopInSequence() {
        animationTask?.cancel()

        animationTask = Task { @MainActor in
            try? await Task.sleep(for: .seconds(1.5))
            guard Task.isCancelled == false else { return }

            withAnimation(.easeInOut(duration: 0.5)) {
                logoCenterOffset = 0
            }

            try? await Task.sleep(for: .seconds(0.25))
            guard Task.isCancelled == false else { return }

            withAnimation(.easeIn(duration: 0.4)) {
                titleOpacity = 1.0
            }

            try? await Task.sleep(for: .seconds(0.15))
            guard Task.isCancelled == false else { return }

            withAnimation(.easeIn(duration: 0.4)) {
                subtitleOpacity = 1.0
            }

            try? await Task.sleep(for: .seconds(0.4))
            guard Task.isCancelled == false else { return }

            withAnimation(.easeIn(duration: 0.4)) {
                buttonOpacity = 1.0
            }
        }
    }
}
