import SwiftUI

struct OnboardingWelcomeScreen: View {
    let onContinue: () -> Void

    @State private var logoScale: CGFloat = 0.12
    @State private var logoOpacity: Double = 0
    @State private var logoCenterOffset: CGFloat = 0
    @State private var titleOpacity: Double = 0
    @State private var subtitleOpacity: Double = 0
    @State private var buttonOpacity: Double = 0
    @State private var popWorkItem: DispatchWorkItem?
    @State private var settleWorkItem: DispatchWorkItem?

    var body: some View {
        GeometryReader { geometry in
            AppScrollScreen(scrollDisabled: true) {
                VStack(spacing: 0) {
                    Spacer()
                        .frame(height: 50)

                    LogoBarView(size: 100)
                        .padding(.bottom, 32)
                        .scaleEffect(logoScale)
                        .opacity(logoOpacity)
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
                runAnimationSequence()
            }
        }
    }

    private func runAnimationSequence() {
        // Cancel any pending animations
        popWorkItem?.cancel()
        popWorkItem = nil
        settleWorkItem?.cancel()
        settleWorkItem = nil

        // Step 0: Wait 0.7 seconds before doing anything
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.7) {
            // Phase 1: Quick reveal to 0.92
            self.logoOpacity = 1.0
            withAnimation(.easeOut(duration: 0.15)) {
                self.logoScale = 0.92
            }

            // Phase 2: Pop overshoot to 1.16
            let pop = DispatchWorkItem {
                withAnimation(.easeOut(duration: 0.2)) {
                    self.logoScale = 1.16
                }
            }
            self.popWorkItem = pop
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2, execute: pop)

            // Phase 3: Settle to 1.0
            let settle = DispatchWorkItem {
                withAnimation(.easeInOut(duration: 0.3)) {
                    self.logoScale = 1.0
                }
            }
            self.settleWorkItem = settle
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.25, execute: settle)

            // Wait 1.5 seconds after pop-in completes, then slide up
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                // Slide logo up from center to final position
                withAnimation(.easeInOut(duration: 0.5)) {
                    self.logoCenterOffset = 0
                }

                // Text fade in staggered as logo approaches stop
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
                    withAnimation(.easeIn(duration: 0.4)) {
                        self.titleOpacity = 1.0
                    }

                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                        withAnimation(.easeIn(duration: 0.4)) {
                            self.subtitleOpacity = 1.0
                        }

                        // Fade in button after all other animations complete
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                            withAnimation(.easeIn(duration: 0.4)) {
                                self.buttonOpacity = 1.0
                            }
                        }
                    }
                }
            }
        }
    }
}
