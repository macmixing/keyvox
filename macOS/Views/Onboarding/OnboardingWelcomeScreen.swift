import SwiftUI

struct OnboardingWelcomeScreen: View {
    let onContinue: () -> Void

    @State private var logoCenterOffset: CGFloat = 0
    @State private var logoScale: CGFloat = 0.12
    @State private var logoOpacity: Double = 0
    @State private var titleOpacity: Double = 0
    @State private var subtitleOpacity: Double = 0
    @State private var buttonOpacity: Double = 0
    @State private var animationTask: Task<Void, Never>?

    var body: some View {
        GeometryReader { geometry in
            VStack(spacing: 0) {
                Spacer()
                    .frame(height: 50)

                LogoBarView(size: 75)
                    .scaleEffect(logoScale)
                    .opacity(logoOpacity)
                    .padding(.bottom, 32)
                    .offset(y: logoCenterOffset)

                Text("Welcome to KeyVox")
                    .font(.appFont(34))
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.center)
                    .padding(.bottom, 8)
                    .opacity(titleOpacity)

                Text("Free Your Voice")
                    .font(.appFont(22, variant: .light))
                    .foregroundStyle(.white.opacity(0.8))
                    .multilineTextAlignment(.center)
                    .opacity(subtitleOpacity)

                Spacer()

                AppActionButton(
                    title: "Let's go",
                    style: .primary,
                    minWidth: 240,
                    action: onContinue
                )
                .opacity(buttonOpacity)
                .padding(.bottom, 34)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .onAppear {
                prepareAnimation(in: geometry.size)
                startAnimation()
            }
            .onDisappear {
                animationTask?.cancel()
                animationTask = nil
            }
        }
        .frame(width: OnboardingView.preferredWindowSize.width)
        .frame(height: OnboardingView.preferredWindowSize.height)
        .background(MacAppTheme.screenBackground)
    }

    private func prepareAnimation(in size: CGSize) {
        let screenCenter = size.height / 2
        let finalLogoCenterY: CGFloat = 87.5
        logoCenterOffset = screenCenter - finalLogoCenterY
        logoScale = 0.12
        logoOpacity = 0
        titleOpacity = 0
        subtitleOpacity = 0
        buttonOpacity = 0
    }

    private func startAnimation() {
        animationTask?.cancel()

        animationTask = Task { @MainActor in
            try? await Task.sleep(for: .seconds(0.7))
            guard Task.isCancelled == false else { return }

            logoOpacity = 1

            withAnimation(.easeOut(duration: 0.15)) {
                logoScale = 0.92
            }

            try? await Task.sleep(for: .seconds(0.2))
            guard Task.isCancelled == false else { return }

            withAnimation(.easeOut(duration: 0.2)) {
                logoScale = 1.16
            }

            try? await Task.sleep(for: .seconds(0.05))
            guard Task.isCancelled == false else { return }

            withAnimation(.easeInOut(duration: 0.3)) {
                logoScale = 1
            }

            try? await Task.sleep(for: .seconds(1.25))
            guard Task.isCancelled == false else { return }

            withAnimation(.easeInOut(duration: 0.5)) {
                logoCenterOffset = 0
            }

            try? await Task.sleep(for: .seconds(0.75))
            guard Task.isCancelled == false else { return }

            withAnimation(.easeIn(duration: 0.4)) {
                titleOpacity = 1
            }

            try? await Task.sleep(for: .seconds(0.15))
            guard Task.isCancelled == false else { return }

            withAnimation(.easeIn(duration: 0.4)) {
                subtitleOpacity = 1
            }

            try? await Task.sleep(for: .seconds(0.4))
            guard Task.isCancelled == false else { return }

            withAnimation(.easeIn(duration: 0.4)) {
                buttonOpacity = 1
            }
        }
    }
}
