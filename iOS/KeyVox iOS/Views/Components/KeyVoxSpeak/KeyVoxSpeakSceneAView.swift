import SwiftUI

struct KeyVoxSpeakSceneAView: View {
    private static let demoResourceName = "keyvox-speak-demo"

    @EnvironmentObject private var ttsPreviewPlayer: TTSPreviewPlayer
    @State private var logoOpacity: Double = 0
    @State private var logoScale: CGFloat = 0.7
    @State private var titleOpacity: Double = 0
    @State private var subtitleOpacity: Double = 0
    @State private var demoCardOpacity: Double = 0
    @State private var demoCardOffset: CGFloat = 18
    @State private var pulseScale: CGFloat = 1.0
    @State private var animationTask: Task<Void, Never>?
    @State private var hasAnimated = false

    var body: some View {
        VStack(spacing: 0) {
            Spacer(minLength: 24)

            LogoBarView(size: 80)
                .opacity(logoOpacity)
                .scaleEffect(logoScale)
                .padding(.bottom, 28)

            Text("KeyVox Speak")
                .font(.appFont(32, variant: .medium))
                .foregroundStyle(.white)
                .opacity(titleOpacity)
                .padding(.bottom, 6)

            Text("Your text, spoken aloud.")
                .font(.appFont(18, variant: .light))
                .foregroundStyle(.white.opacity(0.78))
                .opacity(subtitleOpacity)
                .padding(.bottom, 36)

            keyVoxSpeakDemoCard
                .opacity(demoCardOpacity)
                .offset(y: demoCardOffset)

            Spacer(minLength: 24)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.horizontal, 24)
        .onAppear { startEntrance() }
        .onDisappear { stopEntrance() }
    }

    private var keyVoxSpeakDemoCard: some View {
        let isActive = ttsPreviewPlayer.isActive(resourceName: Self.demoResourceName)
        let isPlaying = isActive && ttsPreviewPlayer.isPlaying
        let symbolName = isPlaying ? "pause.circle.fill" : "play.circle.fill"
        let canPlayPreview = ttsPreviewPlayer.hasPreview(resourceName: Self.demoResourceName)

        return Button {
            ttsPreviewPlayer.togglePlayback(resourceName: Self.demoResourceName)
        } label: {
            HStack(spacing: 14) {
                Image(systemName: symbolName)
                    .font(.system(size: 42, weight: .regular))
                    .foregroundStyle(canPlayPreview ? .yellow : .white.opacity(0.28))
                    .scaleEffect(pulseScale)
                    .shadow(color: .yellow.opacity(isPlaying ? 0.5 : 0.25), radius: isPlaying ? 12 : 6)

                VStack(alignment: .leading, spacing: 3) {
                    Text("Hear from Alba")
                        .font(.appFont(16, variant: .medium))
                        .foregroundStyle(.white)

                    Text("\"Welcome to KeyVox Speak.\"")
                        .font(.appFont(14, variant: .light))
                        .foregroundStyle(.white.opacity(0.6))
                        .lineLimit(1)
                }

                Spacer(minLength: 0)

                if isPlaying {
                    waveformIndicator
                }
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 14)
            .background(
                RoundedRectangle(cornerRadius: AppTheme.cardCornerRadius)
                    .fill(Color.white.opacity(0.07))
                    .overlay(
                        RoundedRectangle(cornerRadius: AppTheme.cardCornerRadius)
                            .stroke(isPlaying ? Color.yellow.opacity(0.35) : Color.white.opacity(0.12), lineWidth: 1)
                    )
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(!canPlayPreview)
        .animation(.easeInOut(duration: 0.3), value: isPlaying)
        .accessibilityLabel(isPlaying ? "Pause KeyVox Speak demo" : "Play KeyVox Speak demo")
    }

    private var waveformIndicator: some View {
        HStack(spacing: 3) {
            ForEach(0..<3, id: \.self) { index in
                RoundedRectangle(cornerRadius: 1.5)
                    .fill(.yellow)
                    .frame(width: 3, height: 12)
                    .scaleEffect(y: pulseScale, anchor: .center)
                    .animation(
                        .easeInOut(duration: 0.4)
                        .repeatForever(autoreverses: true)
                        .delay(Double(index) * 0.15),
                        value: pulseScale
                    )
            }
        }
    }

    private func startEntrance() {
        guard !hasAnimated else { return }
        hasAnimated = true
        
        stopEntrance()
        logoOpacity = 0
        logoScale = 0.7
        titleOpacity = 0
        subtitleOpacity = 0
        demoCardOpacity = 0
        demoCardOffset = 18

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

            try? await Task.sleep(for: .seconds(0.25))
            guard !Task.isCancelled else { return }

            withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                demoCardOpacity = 1
                demoCardOffset = 0
            }

            try? await Task.sleep(for: .seconds(0.3))
            guard !Task.isCancelled else { return }

            withAnimation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true)) {
                pulseScale = 1.08
            }
        }
    }

    private func stopEntrance() {
        animationTask?.cancel()
        animationTask = nil
    }
}
