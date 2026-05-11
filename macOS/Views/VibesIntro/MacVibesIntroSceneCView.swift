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
        Detail(id: Self.downloadDetailID, icon: "arrow.down.circle.fill", title: "Download Vibes AI", subtitle: "Install the local model that powers KeyVox Vibes."),
        Detail(id: 1, icon: "text.bubble.fill", title: "Pick a Style", subtitle: "Choose Casual, Polished, or Chill before you dictate.")
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

            Text("Get Vibes Ready")
                .font(.appFont(31, variant: .medium))
                .foregroundStyle(.white)
                .multilineTextAlignment(.center)
                .opacity(titleOpacity)
                .padding(.bottom, 6)

            Text("Download Vibes AI once, then try writing styles locally.")
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

            Text(isReadyDownloadDetail ? "Vibes AI is Ready" : detail.title)
                .font(.appFont(16, variant: .medium))
                .foregroundStyle(.white)
                .multilineTextAlignment(.center)

            Text(isReadyDownloadDetail ? "You're all set to experience a new kind of vibe." : detail.subtitle)
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

                Text("Install Vibes AI")
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
            return "Download"
        case .failed:
            return "Repair"
        case .downloading, .installing, .ready:
            return nil
        }
    }
}
