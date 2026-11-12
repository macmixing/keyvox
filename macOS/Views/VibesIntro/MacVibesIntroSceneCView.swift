import Foundation
import SwiftUI

struct MacVibesIntroSceneCView: View {
    private struct Detail: Identifiable {
        let id: Int
        let icon: String
        let title: String
        let subtitle: String
    }

    private static let downloadDetailID = 0

    private static let details: [Detail] = [
        Detail(id: Self.downloadDetailID, icon: "arrow.down.circle.fill", title: String(localized: "Download Vibes AI", comment: "Step title on the setup page of the KeyVox Vibes introduction window. Vibes AI is a brand name and stays in English."), subtitle: String(localized: "Install the local model that powers KeyVox Vibes.", comment: "Step description on the setup page of the KeyVox Vibes introduction window. KeyVox Vibes is a brand name and stays in English.")),
        Detail(id: 1, icon: "text.bubble.fill", title: String(localized: "Pick a Style", comment: "Step title on the setup page of the KeyVox Vibes introduction window."), subtitle: String(localized: "Choose Casual, Polished, or Chill before you dictate.", comment: "Step description on the setup page of the KeyVox Vibes introduction window. Casual, Polished and Chill are brand names of writing styles and stay in English."))
    ]

    let isVisible: Bool
    let installState: MacLocalRewriteModelInstallState
    let downloadAction: () -> Void

    @State private var logoOpacity: Double = 0
    @State private var logoScale: CGFloat = 0.7
    @State private var titleOpacity: Double = 0
    @State private var subtitleOpacity: Double = 0
    @State private var rowRevealProgress: Int = 0
    @State private var footerOpacity: Double = 0
    @State private var animationTask: Task<Void, Never>?
    @State private var hasAnimated = false

    var body: some View {
        VStack(spacing: 0) {
            Image("vibes-circle-fill")
                .resizable()
                .scaledToFit()
                .frame(width: 64, height: 64)
                .opacity(logoOpacity)
                .scaleEffect(logoScale)
                .padding(.bottom, 12)

            Text("Get Vibes Ready", comment: "Title of the setup page of the KeyVox Vibes introduction window. Vibes is a brand name and stays in English.")
                .font(.appFont(31, variant: .medium))
                .foregroundStyle(.white)
                .multilineTextAlignment(.center)
                .opacity(titleOpacity)
                .padding(.bottom, 6)

            Text("Download Vibes AI once, then try writing styles locally.", comment: "Subtitle of the setup page of the KeyVox Vibes introduction window. Vibes AI is a brand name and stays in English.")
                .font(.appFont(17, variant: .light))
                .foregroundStyle(.white.opacity(0.78))
                .multilineTextAlignment(.center)
                .opacity(subtitleOpacity)
                .padding(.bottom, 16)

            VStack(spacing: 0) {
                ForEach(Self.details) { detail in
                    detailSpotlight(
                        detail,
                        isReadyDownloadDetail: installState.isReady && detail.id == Self.downloadDetailID
                    )
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
            .padding(.bottom, 12)

            installCardSlot
                .opacity(footerOpacity)
        }
        .frame(maxWidth: .infinity)
        .onAppear {
            handleVisibilityChange(isVisible)
        }
        .onChange(of: isVisible) { visible in
            handleVisibilityChange(visible)
        }
        .onDisappear {
            stopEntrance()
        }
    }

    private func handleVisibilityChange(_ visible: Bool) {
        guard visible else { return }
        startEntranceIfNeeded()
    }

    private func detailSpotlight(_ detail: Detail, isReadyDownloadDetail: Bool) -> some View {
        VStack(spacing: 4) {
            Image(systemName: isReadyDownloadDetail ? "checkmark.circle.fill" : detail.icon)
                .font(.system(size: 18, weight: .medium))
                .foregroundStyle(isReadyDownloadDetail ? .green : .yellow)

            Text(isReadyDownloadDetail ? String(localized: "Vibes AI is Ready", comment: "Step title on the setup page of the KeyVox Vibes introduction window after the Vibes model is installed. Vibes AI is a brand name and stays in English.") : detail.title)
                .font(.appFont(16, variant: .medium))
                .foregroundStyle(.white)
                .multilineTextAlignment(.center)

            Text(isReadyDownloadDetail ? String(localized: "You're all set to experience a new kind of vibe.", comment: "Step description on the setup page of the KeyVox Vibes introduction window after the Vibes model is installed.") : detail.subtitle)
                .font(.appFont(15, variant: .light))
                .foregroundStyle(.white.opacity(0.55))
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
    }

    private var installCardSlot: some View {
        Group {
            if shouldShowInstallCard(for: installState) {
                MacVibesIntroInstallCard(
                    state: installState,
                    action: downloadAction
                )
                .padding(.bottom, 14)
            }
        }
    }

    private func shouldShowInstallCard(for state: MacLocalRewriteModelInstallState) -> Bool {
        switch state {
        case .ready:
            return false
        case .notInstalled, .downloading, .installing, .failed:
            return true
        }
    }

    private func startEntranceIfNeeded() {
        guard hasAnimated == false else { return }
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
            guard Task.isCancelled == false else { return }

            withAnimation(.spring(response: 0.55, dampingFraction: 0.78)) {
                logoOpacity = 1
                logoScale = 1.0
            }

            try? await Task.sleep(for: .seconds(0.35))
            guard Task.isCancelled == false else { return }

            withAnimation(.easeOut(duration: 0.4)) {
                titleOpacity = 1
            }

            try? await Task.sleep(for: .seconds(0.15))
            guard Task.isCancelled == false else { return }

            withAnimation(.easeOut(duration: 0.4)) {
                subtitleOpacity = 1
            }

            for index in Self.details.indices {
                try? await Task.sleep(for: .seconds(0.12))
                guard Task.isCancelled == false else { return }

                withAnimation(.spring(response: 0.4, dampingFraction: 0.82)) {
                    rowRevealProgress = index + 1
                }
            }

            try? await Task.sleep(for: .seconds(0.18))
            guard Task.isCancelled == false else { return }

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

private extension MacLocalRewriteModelInstallState {
    var isReady: Bool {
        if case .ready = self {
            return true
        }

        return false
    }
}

private struct MacVibesIntroInstallCard: View {
    let state: MacLocalRewriteModelInstallState
    let action: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .center, spacing: 12) {
                Circle()
                    .fill(MacAppTheme.iconFill)
                    .frame(width: 24, height: 24)
                    .overlay(Circle().stroke(Color.yellow.opacity(0.4), lineWidth: 0.5))
                    .overlay {
                        Image(systemName: "arrowshape.down.fill")
                            .font(.system(size: 11, weight: .heavy))
                            .foregroundStyle(.yellow)
                    }

                Text("Install Vibes AI", comment: "Title of the install row on the setup page of the KeyVox Vibes introduction window. Vibes AI is a brand name and stays in English.")
                    .font(.appFont(15, variant: .medium))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity, alignment: .leading)

                if let actionTitle, progress == nil {
                    AppActionButton(
                        title: actionTitle,
                        style: .primary,
                        minWidth: 84,
                        action: action
                    )
                }
            }

            if let progress {
                LabeledProgressBar(progress: progress, statusText: statusText)
            } else {
                Text(statusText)
                    .font(.appFont(13, variant: .light))
                    .foregroundStyle(.white.opacity(0.62))
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

            if let errorText {
                Text(errorText)
                    .font(.system(size: 12))
                    .foregroundStyle(.red)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(MacAppTheme.rowFill)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(MacAppTheme.rowStroke, lineWidth: 1)
                )
        )
    }

    private var statusText: String {
        switch state {
        case .notInstalled:
            return String(localized: "Install Vibes AI first (\(ApproximateDownloadSize.vibesAI)), then you can use KeyVox Vibes.", comment: "Status on the setup page of the KeyVox Vibes introduction window before the Vibes model is installed. The placeholder in parentheses is the approximate download size. Vibes AI and KeyVox Vibes are brand names and stay in English.")
        case .downloading:
            return String(localized: "Downloading KeyVox Vibes AI.", comment: "Progress label on the setup page of the KeyVox Vibes introduction window while the Vibes model downloads. KeyVox Vibes AI is a brand name and stays in English.")
        case .installing:
            return String(localized: "Installing KeyVox Vibes AI.", comment: "Progress label on the setup page of the KeyVox Vibes introduction window while the Vibes model installs. KeyVox Vibes AI is a brand name and stays in English.")
        case .ready:
            return String(localized: "KeyVox Vibes AI is installed and ready.", comment: "Status on the setup page of the KeyVox Vibes introduction window when the Vibes model is installed. KeyVox Vibes AI is a brand name and stays in English.")
        case .failed:
            return String(localized: "Install failed.", comment: "Status on the setup page of the KeyVox Vibes introduction window when the Vibes model install fails.")
        }
    }

    private var progress: Double? {
        switch state {
        case .downloading(let progress), .installing(let progress):
            return progress
        case .notInstalled, .ready, .failed:
            return nil
        }
    }

    private var errorText: String? {
        if case .failed(let message) = state {
            return message
        }
        return nil
    }

    private var actionTitle: String? {
        switch state {
        case .notInstalled:
            return String(localized: "Download", comment: "Button on the setup page of the KeyVox Vibes introduction window that downloads the Vibes model.")
        case .failed:
            return String(localized: "Repair", comment: "Button on the setup page of the KeyVox Vibes introduction window that downloads the Vibes model again after a failed install.")
        case .downloading, .installing, .ready:
            return nil
        }
    }
}
