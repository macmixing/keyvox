import SwiftUI

struct KeyVoxVibesUnlockScene: View {
    private static var installCardAnimation: Animation {
        Animation.spring(response: 0.62, dampingFraction: 0.88)
    }

    private static var installCardCollapseDelayNanoseconds: UInt64 {
        700_000_000
    }

    private struct Benefit: Identifiable {
        let id: Int
        let icon: String
        let title: String
        let subtitle: String
    }

    private static let benefits: [Benefit] = [
        Benefit(id: 0, icon: "infinity", title: "Vibe Forever", subtitle: "Unlock once and keep every built-in Vibe."),
        Benefit(id: 1, icon: "hand.tap.fill", title: "Long Press Included", subtitle: "Restyle or undo the latest untouched dictation."),
        Benefit(id: 2, icon: "desktopcomputer", title: "Available on Mac", subtitle: "KeyVox Vibes is also available on Mac.")
    ]

    @Environment(\.appHaptics) private var appHaptics
    @EnvironmentObject private var vibesPurchaseController: KeyVoxVibesPurchaseController
    @EnvironmentObject private var localRewriteModelManager: LocalRewriteModelManager

    let isVisible: Bool
    let onDownloadRequested: (PendingDownloadConfirmation) -> Void

    @State private var logoOpacity: Double = 0
    @State private var logoScale: CGFloat = 0.7
    @State private var titleOpacity: Double = 0
    @State private var subtitleOpacity: Double = 0
    @State private var rowRevealProgress: Int = 0
    @State private var footerOpacity: Double = 0
    @State private var animationTask: Task<Void, Never>?
    @State private var displayedInstallState: LocalRewriteModelInstallState?
    @State private var isInstallCardVisible = false
    @State private var installCardHeight: CGFloat = 0
    @State private var installCardCollapseTask: Task<Void, Never>?
    @State private var hasAnimated = false

    var body: some View {
        GeometryReader { geometry in
            ScrollView {
                VStack(spacing: 0) {
                    Spacer(minLength: 20)

                    Image("vibes-circle-fill")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 60, height: 60)
                        .opacity(logoOpacity)
                        .scaleEffect(logoScale)
                        .padding(.bottom, 14)

                    Text("Want to Keep Vibing?")
                        .font(.appFont(30, variant: .medium))
                        .foregroundStyle(.white)
                        .multilineTextAlignment(.center)
                        .opacity(titleOpacity)
                        .padding(.bottom, 6)

                    Text(subtitle)
                        .font(.appFont(17, variant: .light))
                        .foregroundStyle(.white.opacity(0.78))
                        .multilineTextAlignment(.center)
                        .opacity(subtitleOpacity)
                        .padding(.bottom, 16)

                    VStack(spacing: 0) {
                        ForEach(Self.benefits) { benefit in
                            benefitSpotlight(benefit)
                                .opacity(benefit.id < rowRevealProgress ? 1 : 0)
                                .offset(y: benefit.id < rowRevealProgress ? 0 : 12)

                            if benefit.id < Self.benefits.count - 1 {
                                Rectangle()
                                    .fill(Color.white.opacity(0.12))
                                    .frame(height: 1)
                                    .padding(.horizontal, 32)
                                    .opacity(benefit.id + 1 < rowRevealProgress ? 1 : 0)
                            }
                        }
                    }
                    .padding(.bottom, 14)

                    installCardSlot

                    Text("One-time purchase. No subscription.")
                        .font(.appFont(15, variant: .light))
                        .foregroundStyle(.yellow.opacity(0.72))
                        .frame(maxWidth: .infinity, alignment: .center)
                        .opacity(footerOpacity)

                    Spacer(minLength: 16)
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
            syncInstallCardVisibility(for: localRewriteModelManager.installState)
        }
        .onChange(of: localRewriteModelManager.installState) { _, newState in
            syncInstallCardVisibility(for: newState)
        }
        .onDisappear {
            stopEntrance()
            installCardCollapseTask?.cancel()
        }
    }

    private var subtitle: String {
        if vibesPurchaseController.isTrialActive {
            return "Your trial has \(vibesPurchaseController.trialRemainingText) left."
        }

        return "Experience Vibes for life."
    }

    private func benefitSpotlight(_ benefit: Benefit) -> some View {
        VStack(spacing: 4) {
            Image(systemName: benefit.icon)
                .font(.system(size: 18, weight: .medium))
                .foregroundStyle(.yellow)

            Text(benefit.title)
                .font(.appFont(16, variant: .medium))
                .foregroundStyle(.white)
                .multilineTextAlignment(.center)

            Text(benefit.subtitle)
                .font(.appFont(15, variant: .light))
                .foregroundStyle(.white.opacity(0.55))
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
    }

    private var installCardSlot: some View {
        vibesAIInstallCard
            .opacity(isInstallCardVisible ? footerOpacity : 0)
            .frame(height: isInstallCardVisible ? installCardHeight : 0, alignment: .top)
            .padding(.bottom, isInstallCardVisible ? 14 : 0)
            .clipped()
            .allowsHitTesting(isInstallCardVisible)
            .accessibilityHidden(!isInstallCardVisible)
            .animation(Self.installCardAnimation, value: isInstallCardVisible)
            .animation(Self.installCardAnimation, value: installCardHeight)
            .background(alignment: .top) {
                if displayedInstallState != nil {
                    installCardMeasurement
                }
            }
    }

    @ViewBuilder
    private var vibesAIInstallCard: some View {
        if let displayedInstallState {
            ModelDownloaderCardView(
                iconSystemName: "arrowshape.down.fill",
                title: "Install Vibes AI",
                subtitle: nil,
                statusText: vibesAIInstallStatusText(for: displayedInstallState),
                progress: vibesAIProgress(for: displayedInstallState),
                progressText: vibesAIProgressText(for: displayedInstallState),
                errorText: vibesAIErrorText(for: displayedInstallState),
                actionTitle: vibesAIActionTitle(for: displayedInstallState),
                actionStyle: .primary,
                isActionEnabled: true,
                action: handleVibesAIAction
            )
        }
    }

    private var installCardMeasurement: some View {
        vibesAIInstallCard
            .fixedSize(horizontal: false, vertical: true)
            .hidden()
            .allowsHitTesting(false)
            .accessibilityHidden(true)
            .background(
                GeometryReader { geometry in
                    Color.clear
                        .onAppear {
                            updateInstallCardHeight(geometry.size.height)
                        }
                        .onChange(of: geometry.size.height) { _, newHeight in
                            updateInstallCardHeight(newHeight)
                        }
                }
            )
    }

    private func shouldShowInstallCard(for state: LocalRewriteModelInstallState) -> Bool {
        switch state {
        case .ready:
            return false
        case .notInstalled, .downloading, .installing, .failed:
            return true
        }
    }

    private func vibesAIInstallStatusText(for state: LocalRewriteModelInstallState) -> String {
        switch state {
        case .notInstalled:
            return "Install Vibes AI first (~491 MB), then you can use KeyVox Vibes."
        case .downloading:
            return "Downloading KeyVox Vibes AI."
        case .installing:
            return "Installing KeyVox Vibes AI."
        case .ready:
            return "KeyVox Vibes AI is installed and ready."
        case .failed:
            return "Install failed."
        }
    }

    private func vibesAIProgress(for state: LocalRewriteModelInstallState) -> Double? {
        switch state {
        case .downloading(let progress), .installing(let progress):
            return progress
        case .notInstalled, .ready, .failed:
            return nil
        }
    }

    private func vibesAIProgressText(for state: LocalRewriteModelInstallState) -> String? {
        guard let progress = vibesAIProgress(for: state) else { return nil }
        return "\(Int((progress * 100).rounded()))%"
    }

    private func vibesAIErrorText(for state: LocalRewriteModelInstallState) -> String? {
        if case .failed(let message) = state {
            return message
        }
        return nil
    }

    private func vibesAIActionTitle(for state: LocalRewriteModelInstallState) -> String? {
        switch state {
        case .notInstalled:
            return "Download"
        case .failed:
            return "Repair"
        case .downloading, .installing, .ready:
            return nil
        }
    }

    private func updateInstallCardHeight(_ newHeight: CGFloat) {
        guard newHeight > 0 else { return }
        guard abs(installCardHeight - newHeight) > 0.5 else { return }
        installCardHeight = newHeight
    }

    private func syncInstallCardVisibility(for state: LocalRewriteModelInstallState) {
        if shouldShowInstallCard(for: state) {
            installCardCollapseTask?.cancel()
            displayedInstallState = state

            guard isInstallCardVisible == false else { return }
            withAnimation(Self.installCardAnimation) {
                isInstallCardVisible = true
            }
            return
        }

        guard displayedInstallState != nil || isInstallCardVisible else { return }
        installCardCollapseTask?.cancel()

        withAnimation(Self.installCardAnimation) {
            isInstallCardVisible = false
        }

        installCardCollapseTask = Task { @MainActor in
            try? await Task.sleep(nanoseconds: Self.installCardCollapseDelayNanoseconds)
            guard Task.isCancelled == false else { return }
            displayedInstallState = nil
        }
    }

    private func handleVibesAIAction() {
        appHaptics.light()

        switch localRewriteModelManager.installState {
        case .notInstalled:
            onDownloadRequested(.keyVoxVibesAI)
        case .failed:
            localRewriteModelManager.downloadModel()
        case .downloading, .installing, .ready:
            break
        }
    }

    private func startEntranceIfNeeded() {
        guard !hasAnimated else { return }
        hasAnimated = true

        stopEntrance()
        logoOpacity = 0
        logoScale = 0.7
        titleOpacity = 0
        subtitleOpacity = 0
        rowRevealProgress = 0
        footerOpacity = 0

        animationTask = Task { @MainActor in
            try? await Task.sleep(for: .seconds(0.2))
            guard !Task.isCancelled else { return }

            withAnimation(.spring(response: 0.55, dampingFraction: 0.78)) {
                logoOpacity = 1
                logoScale = 1.0
            }

            try? await Task.sleep(for: .seconds(0.35))
            guard !Task.isCancelled else { return }

            withAnimation(.easeOut(duration: 0.4)) {
                titleOpacity = 1
            }

            try? await Task.sleep(for: .seconds(0.15))
            guard !Task.isCancelled else { return }

            withAnimation(.easeOut(duration: 0.4)) {
                subtitleOpacity = 1
            }

            for index in Self.benefits.indices {
                try? await Task.sleep(for: .seconds(0.12))
                guard !Task.isCancelled else { return }

                withAnimation(.spring(response: 0.4, dampingFraction: 0.82)) {
                    rowRevealProgress = index + 1
                }
            }

            try? await Task.sleep(for: .seconds(0.18))
            guard !Task.isCancelled else { return }

            withAnimation(.easeOut(duration: 0.35)) {
                footerOpacity = 1
            }
        }
    }

    private func stopEntrance() {
        animationTask?.cancel()
        animationTask = nil
    }
}
