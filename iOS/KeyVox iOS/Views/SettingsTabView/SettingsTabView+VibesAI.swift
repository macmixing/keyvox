import Foundation
import SwiftUI

extension SettingsTabView {
    private static var vibesAIInstallAnimation: Animation {
        Animation.spring(response: 0.64, dampingFraction: 0.88)
    }

    private static var vibesAIInstallCollapseDelayNanoseconds: UInt64 {
        700_000_000
    }

    @ViewBuilder
    var vibesAISection: some View {
        AppCard {
            VStack(alignment: .leading, spacing: 16) {
                HStack(alignment: .top, spacing: 12) {
                    ZStack {
                        Circle()
                            .fill(AppTheme.accent.opacity(0.4))
                            .frame(width: 32, height: 32)

                        Image("vibes-logo")
                            .resizable()
                            .renderingMode(.template)
                            .scaledToFit()
                            .foregroundStyle(.yellow)
                            .frame(width: 18, height: 18)
                    }

                    Text(verbatim: "KeyVox Vibes AI")
                        .font(.appFont(18))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    vibesAIActionButton
                }

                Divider()
                    .overlay(.white.opacity(0.22))

                VStack(alignment: .leading, spacing: 0) {
                    Text(vibesAISubtitleText)
                        .font(.appFont(15, variant: .light))
                        .foregroundStyle(.white.opacity(0.7))
                        .frame(maxWidth: .infinity, alignment: .leading)

                    vibesAIInstallContent
                        .opacity(shouldShowVibesAIInstallContent ? 1 : 0)
                        .frame(height: shouldShowVibesAIInstallContent ? vibesAIInstallContentHeight : 0, alignment: .top)
                        .padding(.top, shouldShowVibesAIInstallContent ? 16 : 0)
                        .clipped()
                        .allowsHitTesting(shouldShowVibesAIInstallContent)
                        .accessibilityHidden(!shouldShowVibesAIInstallContent)
                        .animation(Self.vibesAIInstallAnimation, value: shouldShowVibesAIInstallContent)
                        .animation(Self.vibesAIInstallAnimation, value: vibesAIInstallContentHeight)
                        .background(alignment: .top) {
                            if displayedVibesAIInstallState != nil {
                                vibesAIInstallContentMeasurement
                            }
                        }
                }
            }
        }
        .onAppear {
            syncVibesAIInstallContentVisibility(for: localRewriteModelManager.installState)
        }
        .onDisappear {
            vibesAIInstallCollapseTask?.cancel()
        }
        .onChange(of: localRewriteModelManager.installState) { _, newState in
            syncVibesAIInstallContentVisibility(for: newState)
        }
    }

    @ViewBuilder
    private var vibesAIInstallContent: some View {
        if let state = displayedVibesAIInstallState {
            VStack(alignment: .leading, spacing: 8) {
                HStack(alignment: .center, spacing: 12) {
                    Text(vibesAIStatusText(for: state))
                        .font(.appFont(14, variant: .light))
                        .foregroundStyle(.white.opacity(0.7))
                        .frame(maxWidth: .infinity, alignment: .leading)

                    if let percentageText = vibesAIProgressPercentageText(for: state) {
                        Text(percentageText)
                            .font(.appFont(14, variant: .medium))
                            .foregroundStyle(.yellow)
                    }
                }

                if case .failed(let message) = state {
                    Text(message)
                        .font(.appFont(12, variant: .light))
                        .foregroundStyle(.red)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }

                if let progress = vibesAIProgress(for: state) {
                    ModelDownloadProgress(progress: progress, showLabel: false)
                }
            }
        }
    }

    private var vibesAIInstallContentMeasurement: some View {
        vibesAIInstallContent
            .fixedSize(horizontal: false, vertical: true)
            .hidden()
            .allowsHitTesting(false)
            .accessibilityHidden(true)
            .background(
                GeometryReader { geometry in
                    Color.clear
                        .onAppear {
                            updateVibesAIInstallContentHeight(geometry.size.height)
                        }
                        .onChange(of: geometry.size.height) { _, newHeight in
                            updateVibesAIInstallContentHeight(newHeight)
                        }
                }
            )
    }

    @ViewBuilder
    private var vibesAIActionButton: some View {
        switch localRewriteModelManager.installState {
        case .notInstalled:
            AppActionButton(
                title: String(localized: "Download", comment: "Button on the KeyVox Vibes AI card in Settings that downloads the model."),
                style: .primary,
                size: .compact,
                fontSize: 15,
                action: {
                    pendingDownloadConfirmation = .keyVoxVibesAI
                }
            )
        case .ready:
            AppActionButton(
                title: String(localized: "Delete", comment: "Button on the KeyVox Vibes AI card in Settings that deletes the model."),
                style: .destructive,
                size: .compact,
                fontSize: 15,
                action: {
                    pendingDeletionConfirmation = .keyVoxVibesAI
                }
            )
        case .failed:
            AppActionButton(
                title: String(localized: "Repair", comment: "Button on the KeyVox Vibes AI card in Settings that retries a failed install."),
                style: .primary,
                size: .compact,
                fontSize: 15,
                action: {
                    localRewriteModelManager.downloadModel()
                }
            )
        case .downloading, .installing:
            EmptyView()
        }
    }

    private var vibesAISubtitleText: String {
        if case .ready = localRewriteModelManager.installState {
            return String(localized: "KeyVox Vibes AI is installed and ready.", comment: "Description on the KeyVox Vibes AI card in Settings once the model is installed. KeyVox Vibes AI is a brand name and stays in English.")
        }

        return String(localized: "Install Vibes AI first (\(ApproximateDownloadSize.vibesAI)), then you can use KeyVox Vibes", comment: "Description on the KeyVox Vibes AI card in Settings when the model is not installed. Vibes AI and KeyVox Vibes are brand names and stay in English. The value in parentheses is the approximate download size.")
    }

    private func vibesAIStatusText(for state: LocalRewriteModelInstallState) -> String {
        switch state {
        case .downloading:
            return String(localized: "Downloading KeyVox Vibes AI.", comment: "Status on the KeyVox Vibes AI card in Settings while the model downloads. KeyVox Vibes AI is a brand name and stays in English.")
        case .installing:
            return String(localized: "Installing KeyVox Vibes AI.", comment: "Status on the KeyVox Vibes AI card in Settings while the model installs. KeyVox Vibes AI is a brand name and stays in English.")
        case .failed:
            return String(localized: "Install failed", comment: "Status on the KeyVox Vibes AI card in Settings when the model failed to install.")
        case .notInstalled, .ready:
            return ""
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

    private func vibesAIProgressPercentageText(for state: LocalRewriteModelInstallState) -> String? {
        guard let progress = vibesAIProgress(for: state) else { return nil }

        return progress.formatted(.percent.precision(.fractionLength(0)).rounded(rule: .toNearestOrAwayFromZero))
    }

    private var shouldShowVibesAIInstallContent: Bool {
        isVibesAIInstallContentVisible && displayedVibesAIInstallState != nil
    }

    func updateVibesAIInstallContentHeight(_ newHeight: CGFloat) {
        guard newHeight > 0 else { return }
        if abs(vibesAIInstallContentHeight - newHeight) > 0.5 {
            vibesAIInstallContentHeight = newHeight
        }
    }

    private func syncVibesAIInstallContentVisibility(for state: LocalRewriteModelInstallState) {
        switch state {
        case .downloading, .installing, .failed:
            vibesAIInstallCollapseTask?.cancel()
            displayedVibesAIInstallState = state

            guard isVibesAIInstallContentVisible == false else { return }
            withAnimation(Self.vibesAIInstallAnimation) {
                isVibesAIInstallContentVisible = true
            }
        case .notInstalled, .ready:
            guard displayedVibesAIInstallState != nil || isVibesAIInstallContentVisible else { return }
            vibesAIInstallCollapseTask?.cancel()
            withAnimation(Self.vibesAIInstallAnimation) {
                isVibesAIInstallContentVisible = false
            }
            vibesAIInstallCollapseTask = Task { @MainActor in
                try? await Task.sleep(nanoseconds: Self.vibesAIInstallCollapseDelayNanoseconds)
                guard Task.isCancelled == false else { return }
                displayedVibesAIInstallState = nil
            }
        }
    }
}
