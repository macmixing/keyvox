import Foundation
import SwiftUI

struct KeyVoxVibesSceneCView: View {
    @Environment(\.appHaptics) private var appHaptics
    @EnvironmentObject private var vibesPurchaseController: KeyVoxVibesPurchaseController
    @EnvironmentObject private var localRewriteModelManager: LocalRewriteModelManager

    private static var installCardAnimation: Animation {
        Animation.spring(response: 0.62, dampingFraction: 0.88)
    }

    private static var installCardCollapseDelayNanoseconds: UInt64 {
        700_000_000
    }

    private struct Detail: Identifiable {
        let id: Int
        let icon: String
        let title: String
        let subtitle: String
    }

    private static let details: [Detail] = [
        Detail(id: 0, icon: "clock.fill", title: String(localized: "Try it now", comment: "Detail title on the KeyVox Vibes trial page."), subtitle: String(localized: "Why not vibe out for a while? You deserve it.", comment: "Detail description on the KeyVox Vibes trial page; a playful invitation to try Vibes.")),
        Detail(id: 1, icon: "infinity", title: String(localized: "No Subscription", comment: "Detail title on the KeyVox Vibes trial page."), subtitle: String(localized: "Pay once and keep the Vibes going.", comment: "Detail description on the KeyVox Vibes trial page. Vibes is a brand name and stays in English.")),
    ]

    let isVisible: Bool
    let variant: KeyVoxVibesSheetView.SceneCVariant
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
                    Spacer(minLength: 24)

                    Image("vibes-circle-fill")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 64, height: 64)
                        .opacity(logoOpacity)
                        .scaleEffect(logoScale)
                        .padding(.bottom, 12)

                    Text("Catch the Vibes", comment: "Title of the KeyVox Vibes trial page. Vibes is a brand name and stays in English.")
                        .font(.appFont(31, variant: .medium))
                        .foregroundStyle(.white)
                        .multilineTextAlignment(.center)
                        .opacity(titleOpacity)
                        .padding(.bottom, 6)

                    Text("Vibe now. Unlock it later.", comment: "Subtitle of the KeyVox Vibes trial page; to Vibe means to restyle text with Vibes. Vibe is a brand name and stays in English.")
                        .font(.appFont(17, variant: .light))
                        .foregroundStyle(.white.opacity(0.78))
                        .multilineTextAlignment(.center)
                        .opacity(subtitleOpacity)
                        .padding(.bottom, 18)

                    VStack(spacing: 0) {
                        ForEach(Self.details) { detail in
                            detailSpotlight(detail)
                                .opacity(detail.id < rowRevealProgress ? 1 : 0)
                                .offset(y: detail.id < rowRevealProgress ? 0 : 12)

                            if detail.id < Self.details.count - 1 {
                                Rectangle()
                                    .fill(Color.white.opacity(0.12))
                                    .frame(height: 1)
                                    .padding(.horizontal, 32)
                                    .opacity(detail.id + 1 < rowRevealProgress ? 1 : 0)
                            }
                        }
                    }
                    .padding(.bottom, 14)

                    installCardSlot

                    Text("\(KeyVoxVibesTrialRemainingTimeFormatter.fullDayCount(for: KeyVoxVibesTrialPolicy.duration))-day trial. One-time purchase.", comment: "Footer on the KeyVox Vibes trial page. %lld is the number of trial days; use plural forms if the language needs them.")
                        .font(.appFont(15, variant: .light))
                        .foregroundStyle(.yellow.opacity(0.72))
                        .opacity(footerOpacity)

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

    private func detailSpotlight(_ detail: Detail) -> some View {
        VStack(spacing: 4) {
            Image(systemName: detail.icon)
                .font(.system(size: 18, weight: .medium))
                .foregroundStyle(.yellow)

            Text(detail.title)
                .font(.appFont(16, variant: .medium))
                .foregroundStyle(.white)
                .multilineTextAlignment(.center)

            Text(subtitle(for: detail))
                .font(.appFont(15, variant: .light))
                .foregroundStyle(subtitleStyle(for: detail))
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
    }

    private func subtitle(for detail: Detail) -> String {
        guard variant == .activeTrialRecovery,
              detail.id == 0 else {
            return detail.subtitle
        }

        let remainingText = KeyVoxVibesTrialRemainingTimeFormatter.remainingText(
            for: vibesPurchaseController.trialRemaining
        )
        return String(localized: "You’re trying Vibes, you have \(remainingText) left.", comment: "Trial status on the KeyVox Vibes trial page. Vibes is a brand name and stays in English. The placeholder is the remaining trial time, such as days and hours.")
    }

    private func subtitleStyle(for detail: Detail) -> Color {
        guard variant == .activeTrialRecovery,
              detail.id == 0 else {
            return .white.opacity(0.55)
        }

        return .yellow
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
                title: String(localized: "Install Vibes AI", comment: "Title of the Vibes AI install card. Vibes AI is a brand name and stays in English."),
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
            return String(localized: "Install Vibes AI first (\(ApproximateDownloadSize.vibesAI)), then you can use KeyVox Vibes.", comment: "Status on the Vibes AI install card before download, with the approximate download size. Vibes AI and KeyVox Vibes are brand names and stay in English.")
        case .downloading:
            return String(localized: "Downloading KeyVox Vibes AI.", comment: "Status on the Vibes AI install card while downloading. KeyVox Vibes AI is a brand name and stays in English.")
        case .installing:
            return String(localized: "Installing KeyVox Vibes AI.", comment: "Status on the Vibes AI install card while installing. KeyVox Vibes AI is a brand name and stays in English.")
        case .ready:
            return String(localized: "KeyVox Vibes AI is installed and ready.", comment: "Status on the Vibes AI install card when installed. KeyVox Vibes AI is a brand name and stays in English.")
        case .failed:
            return String(localized: "Install failed.", comment: "Status on the Vibes AI install card when the install failed.")
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
        return progress.formatted(.percent.precision(.fractionLength(0)).rounded(rule: .toNearestOrAwayFromZero))
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
            return String(localized: "Download", comment: "Button on the Vibes AI install card that starts the download.")
        case .failed:
            return String(localized: "Repair", comment: "Button on the Vibes AI install card that repairs a broken install.")
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

            for index in Self.details.indices {
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
