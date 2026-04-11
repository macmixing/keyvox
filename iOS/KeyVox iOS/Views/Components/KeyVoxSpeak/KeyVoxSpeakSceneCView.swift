import SwiftUI

struct KeyVoxSpeakSceneCView: View {
    @EnvironmentObject private var pocketTTSModelManager: PocketTTSModelManager
    @StateObject private var networkMonitor = OnboardingDownloadNetworkMonitor()

    let isVisible: Bool
    let isUnlockContext: Bool

    @State private var headerOpacity: Double = 0
    @State private var installCardOpacity: Double = 0
    @State private var installCardOffset: CGFloat = 18
    @State private var stepRevealProgress: Int = 0
    @State private var fastModeHintOpacity: Double = 0
    @State private var footerOpacity: Double = 0
    @State private var animationTask: Task<Void, Never>?
    @State private var hasAnimated = false

    var body: some View {
        GeometryReader { geometry in
            ScrollView {
                VStack(spacing: 0) {
                    Spacer(minLength: 20)

                    VStack(spacing: 6) {
                        Text(isUnlockContext ? "Finish Setup" : "Free to Start")
                            .font(.appFont(35, variant: .medium))
                            .foregroundStyle(.white)

                        Text("Install Alba and be ready to speak right away.")
                            .font(.appFont(18, variant: .light))
                            .foregroundStyle(.white.opacity(0.7))
                            .multilineTextAlignment(.center)
                    }
                    .opacity(headerOpacity)
                    .padding(.bottom, 10)

                    Text("You can download up to 8 total voices in Settings.")
                        .font(.appFont(16, variant: .medium))
                        .foregroundStyle(.yellow)
                        .multilineTextAlignment(.center)
                        .opacity(headerOpacity)
                        .padding(.bottom, 20)

                    KeyVoxSpeakInstallCardView(
                        revealedStepCount: stepRevealProgress
                    )
                    .opacity(installCardOpacity)
                    .offset(y: installCardOffset)

                    if networkMonitor.isOnCellular && !pocketTTSReadyForAlba {
                        Text("Wi-Fi is recommended for this download.")
                            .font(.appFont(14, variant: .light))
                            .foregroundStyle(.yellow)
                            .multilineTextAlignment(.center)
                            .opacity(footerOpacity)
                            .padding(.top, 18)
                    }

                    setupHint
                        .opacity(footerOpacity)
                        .padding(.top, 12)

                    fastModeHint
                        .opacity(fastModeHintOpacity)
                        .padding(.top, 10)

                    Spacer(minLength: 48)
                }
                .frame(maxWidth: .infinity, minHeight: geometry.size.height)
            }
            .scrollIndicators(.hidden)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.horizontal, 24)
        .onChange(of: isVisible, initial: true) { _, visible in
            guard visible else { return }
            startEntranceIfNeeded()
        }
    }

    private var albaVoiceState: PocketTTSInstallState {
        pocketTTSModelManager.installState(for: .alba)
    }

    private var sharedModelState: PocketTTSInstallState {
        pocketTTSModelManager.sharedModelInstallState
    }

    private var pocketTTSReadyForAlba: Bool {
        if case .ready = sharedModelState,
           case .ready = albaVoiceState {
            return true
        }
        return false
    }

    private var setupHintText: String {
        if pocketTTSReadyForAlba {
            return "Alba is ready. You can start KeyVox Speak from the Home tab now."
        }

        if case .ready = sharedModelState {
            return "PocketTTS is ready. Finish installing Alba and you'll be ready to speak."
        }

        return "Install Alba and KeyVox will take care of the PocketTTS setup for you."
    }

    private var fastModeHint: some View {
        HStack(spacing: 8) {
            Image(systemName: "bolt.fill")
                .font(.system(size: 18, weight: .medium))
                .foregroundStyle(.yellow.opacity(0.8))

            Text("Don't forget: Fast Mode starts speaking ~50% faster.")
                .font(.appFont(15, variant: .light))
                .foregroundStyle(.white.opacity(0.55))
        }
        .frame(maxWidth: .infinity, alignment: .center)
    }

    private var setupHint: some View {
        HStack(spacing: 8) {
            Image(systemName: pocketTTSReadyForAlba ? "house.circle.fill" : "arrow.forward.circle.fill")
                .font(.system(size: 25, weight: .heavy))
                .foregroundStyle(.yellow.opacity(0.8))

            Text(setupHintText)
                .font(.appFont(15, variant: .light))
                .foregroundStyle(.white.opacity(0.55))
        }
        .frame(maxWidth: .infinity, alignment: .center)
    }

    private func startEntranceIfNeeded() {
        guard !hasAnimated else { return }
        hasAnimated = true

        stopEntrance()
        headerOpacity = 0
        installCardOpacity = 0
        installCardOffset = 18
        stepRevealProgress = 0
        fastModeHintOpacity = 0
        footerOpacity = 0

        animationTask = Task { @MainActor in
            try? await Task.sleep(for: .seconds(0.15))
            guard !Task.isCancelled else { return }

            withAnimation(.easeOut(duration: 0.4)) {
                headerOpacity = 1
            }

            try? await Task.sleep(for: .seconds(0.18))
            guard !Task.isCancelled else { return }

            withAnimation(.spring(response: 0.5, dampingFraction: 0.82)) {
                installCardOpacity = 1
                installCardOffset = 0
            }

            for index in 0..<KeyVoxSpeakInstallCardView.installStepCount {
                try? await Task.sleep(for: .seconds(0.14))
                guard !Task.isCancelled else { return }

                withAnimation(.spring(response: 0.4, dampingFraction: 0.82)) {
                    stepRevealProgress = index + 1
                }
            }

            try? await Task.sleep(for: .seconds(0.2))
            guard !Task.isCancelled else { return }

            withAnimation(.easeOut(duration: 0.4)) {
                footerOpacity = 1
            }

            try? await Task.sleep(for: .seconds(0.15))
            guard !Task.isCancelled else { return }

            withAnimation(.easeOut(duration: 0.35)) {
                fastModeHintOpacity = 1
            }
        }
    }

    private func stopEntrance() {
        animationTask?.cancel()
        animationTask = nil
    }
}
