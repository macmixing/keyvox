import SwiftUI

struct DictationShortcutSetupPageOneView: View {
    private enum Layout {
        static let contentTopInset: CGFloat = -50
        static let videoSize: CGFloat = 160
    }

    private struct FeatureItem: Identifiable {
        let id: Int
        let symbol: String
        let label: String
    }

    private static let featureItems: [FeatureItem] = [
        FeatureItem(id: 0, symbol: "switch.2", label: "Add to Control Center"),
        FeatureItem(id: 1, symbol: "hand.tap.fill",        label: "Map to Action Button"),
        FeatureItem(id: 2, symbol: "mic.fill",             label: "Dictate in any app, instantly"),
    ]

    let videoAsset: DictationShortcutSetupVideoAsset
    let isActive: Bool
    let animatesEntrance: Bool

    @State private var titleOpacity: Double
    @State private var titleOffset: CGFloat
    @State private var subtitleOpacity: Double
    @State private var videoOpacity: Double
    @State private var videoOffset: CGFloat
    @State private var featureRevealProgress: Int
    @State private var bottomTextOpacity: Double
    @State private var animationTask: Task<Void, Never>?
    @State private var hasAnimated: Bool

    init(
        videoAsset: DictationShortcutSetupVideoAsset,
        isActive: Bool,
        animatesEntrance: Bool
    ) {
        self.videoAsset = videoAsset
        self.isActive = isActive
        self.animatesEntrance = animatesEntrance

        let showsCompletedState = animatesEntrance == false
        _titleOpacity = State(initialValue: showsCompletedState ? 1 : 0)
        _titleOffset = State(initialValue: showsCompletedState ? 0 : 14)
        _subtitleOpacity = State(initialValue: showsCompletedState ? 1 : 0)
        _videoOpacity = State(initialValue: showsCompletedState ? 1 : 0)
        _videoOffset = State(initialValue: showsCompletedState ? 0 : 18)
        _featureRevealProgress = State(
            initialValue: showsCompletedState ? Self.featureItems.count : 0
        )
        _bottomTextOpacity = State(initialValue: showsCompletedState ? 1 : 0)
        _hasAnimated = State(initialValue: showsCompletedState)
    }

    var body: some View {
        GeometryReader { geometry in
            ScrollView {
                VStack(spacing: 0) {
                    VStack(spacing: 10) {
                        Text("Dictate Anywhere")
                            .font(.appFont(35, variant: .medium))
                            .foregroundStyle(.white)
                            .multilineTextAlignment(.center)
                            .opacity(titleOpacity)
                            .offset(y: titleOffset)

                        Text("Use it from Control Center,\nthe Action Button, and more.")
                            .font(.appFont(17, variant: .light))
                            .foregroundStyle(.white.opacity(0.72))
                            .multilineTextAlignment(.center)
                            .opacity(subtitleOpacity)
                    }
                    .padding(.bottom, 28)

                    DictationShortcutSetupVideoView(
                        asset: videoAsset,
                        isActive: isActive
                    )
                    .frame(width: Layout.videoSize, height: Layout.videoSize)
                    .accessibilityHidden(true)
                    .opacity(videoOpacity)
                    .offset(y: videoOffset)
                    .padding(.bottom, 28)

                    VStack(spacing: 10) {
                        ForEach(Self.featureItems) { item in
                            featureRow(item)
                                .opacity(item.id < featureRevealProgress ? 1 : 0)
                                .offset(y: item.id < featureRevealProgress ? 0 : 12)
                        }
                    }
                    .padding(.bottom, 20)

                    Text("Setup only takes a few quick steps.")
                        .font(.appFont(15, variant: .light))
                        .foregroundStyle(.white.opacity(0.5))
                        .multilineTextAlignment(.center)
                        .opacity(bottomTextOpacity)

                    Spacer(minLength: 48)
                }
                .frame(maxWidth: .infinity, minHeight: geometry.size.height, alignment: .top)
                .padding(.top, Layout.contentTopInset)
            }
            .scrollIndicators(.hidden)
            .scrollClipDisabled()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.horizontal, AppTheme.screenPadding)
        .onChange(of: isActive, initial: true) { _, active in
            guard active, animatesEntrance else { return }
            startEntranceIfNeeded()
        }
    }

    private func featureRow(_ item: FeatureItem) -> some View {
        HStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(AppTheme.accent.opacity(0.4))
                    .frame(width: 34, height: 34)

                Image(systemName: item.symbol)
                    .font(.system(size: 17, weight: .medium))
                    .foregroundStyle(.yellow)
            }

            Text(item.label)
                .font(.appFont(16, variant: .light))
                .foregroundStyle(.white.opacity(0.88))

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: AppTheme.cardCornerRadius)
                .fill(Color.white.opacity(0.06))
                .overlay(
                    RoundedRectangle(cornerRadius: AppTheme.cardCornerRadius)
                        .stroke(Color.white.opacity(0.1), lineWidth: 1)
                )
        )
    }

    private func startEntranceIfNeeded() {
        guard !hasAnimated else { return }
        hasAnimated = true

        animationTask?.cancel()
        titleOpacity = 0
        titleOffset = 14
        subtitleOpacity = 0
        videoOpacity = 0
        videoOffset = 18
        featureRevealProgress = 0
        bottomTextOpacity = 0

        animationTask = Task { @MainActor in
            try? await Task.sleep(for: .seconds(0.2))
            guard !Task.isCancelled else { return }

            withAnimation(.spring(response: 0.5, dampingFraction: 0.82)) {
                titleOpacity = 1
                titleOffset = 0
            }

            try? await Task.sleep(for: .seconds(0.2))
            guard !Task.isCancelled else { return }

            withAnimation(.easeOut(duration: 0.4)) {
                subtitleOpacity = 1
            }

            try? await Task.sleep(for: .seconds(0.3))
            guard !Task.isCancelled else { return }

            withAnimation(.spring(response: 0.5, dampingFraction: 0.82)) {
                videoOpacity = 1
                videoOffset = 0
            }

            for index in Self.featureItems.indices {
                try? await Task.sleep(for: .seconds(0.14))
                guard !Task.isCancelled else { return }

                withAnimation(.spring(response: 0.42, dampingFraction: 0.8)) {
                    featureRevealProgress = index + 1
                }
            }

            try? await Task.sleep(for: .seconds(0.2))
            guard !Task.isCancelled else { return }

            withAnimation(.easeOut(duration: 0.35)) {
                bottomTextOpacity = 1
            }
        }
    }
}
