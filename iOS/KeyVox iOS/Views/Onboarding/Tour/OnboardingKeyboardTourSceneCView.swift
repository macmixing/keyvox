import SwiftUI

struct OnboardingKeyboardTourSceneCView: View {
    private enum Metrics {
        static let checkmarkSize: CGFloat = 70
        static let ringSize: CGFloat = 120
        static let particleCount = 12
    }

    @State private var checkmarkTrim: CGFloat = 0
    @State private var ringScale: CGFloat = 0.5
    @State private var ringOpacity: Double = 0
    @State private var contentOpacity: Double = 0
    @State private var particleOffsets: [CGSize] = Array(repeating: .zero, count: Metrics.particleCount)
    @State private var particleOpacities: [Double] = Array(repeating: 0, count: Metrics.particleCount)
    @State private var isAnimating = false
    private var animationTask: Task<Void, Never>?

    var body: some View {
        VStack(spacing: 32) {
            ZStack {
                successRing
                checkmark
                particles
            }
            .frame(height: Metrics.ringSize)

            VStack(spacing: 8) {
                Text("You're all set")
                    .font(.appFont(24, variant: .medium))
                    .foregroundStyle(.white)

                Text("KeyVox is now ready, anywhere you type.")
                    .font(.appFont(17, variant: .light))
                    .foregroundStyle(.white.opacity(0.8))
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .opacity(contentOpacity)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.top, 30)
        .onAppear {
            startCelebration()
        }
        .onDisappear {
            stopCelebration()
        }
    }

    private var checkmark: some View {
        Image(systemName: "checkmark")
            .font(.system(size: Metrics.checkmarkSize, weight: .heavy))
            .foregroundStyle(.yellow)
            .frame(width: Metrics.checkmarkSize, height: Metrics.checkmarkSize)
            .offset(x: 2, y: 2)
            .mask(
                GeometryReader { geo in
                    Rectangle()
                        .frame(width: geo.size.width * checkmarkTrim)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            )
    }

    private var successRing: some View {
        Circle()
            .stroke(.yellow.opacity(0.3), lineWidth: 3)
            .frame(width: Metrics.ringSize, height: Metrics.ringSize)
            .scaleEffect(ringScale)
            .opacity(ringOpacity)
    }

    private var particles: some View {
        ZStack {
            ForEach(0..<Metrics.particleCount, id: \.self) { index in
                Circle()
                    .fill(.yellow)
                    .frame(width: 6, height: 6)
                    .offset(particleOffsets[index])
                    .opacity(particleOpacities[index])
            }
        }
        .frame(width: Metrics.ringSize, height: Metrics.ringSize)
    }

    private func startCelebration() {
        guard !isAnimating else { return }
        isAnimating = true

        Task { @MainActor in
            await runCelebrationSequence()
        }
    }

    private func runCelebrationSequence() async {
        ringScale = 0.5
        ringOpacity = 0
        checkmarkTrim = 0
        contentOpacity = 0

        try? await Task.sleep(for: .seconds(0.3))

        withAnimation(.easeOut(duration: 0.4)) {
            ringScale = 1.0
            ringOpacity = 1.0
        }

        try? await Task.sleep(for: .seconds(0.1))

        withAnimation(.easeInOut(duration: 0.5)) {
            checkmarkTrim = 1.0
        }

        try? await Task.sleep(for: .seconds(0.3))

        animateParticles()

        withAnimation(.easeInOut(duration: 0.5)) {
            contentOpacity = 1.0
        }

        try? await Task.sleep(for: .seconds(0.5))

        withAnimation(.easeInOut(duration: 1.0).repeatForever(autoreverses: true)) {
            ringOpacity = 0.6
        }
    }

    private func animateParticles() {
        for index in 0..<Metrics.particleCount {
            let angle = Double(index) * (2 * .pi / Double(Metrics.particleCount))
            let distance: CGFloat = 50 + CGFloat.random(in: 10...30)

            let endOffset = CGSize(
                width: cos(angle) * distance,
                height: sin(angle) * distance
            )

            particleOffsets[index] = .zero
            particleOpacities[index] = 0

            withAnimation(
                .easeOut(duration: 0.6)
                .delay(Double(index) * 0.03)
            ) {
                particleOffsets[index] = endOffset
                particleOpacities[index] = 0
            }

            withAnimation(
                .easeInOut(duration: 0.3)
                .delay(Double(index) * 0.03)
            ) {
                particleOpacities[index] = 0.8
            }

            withAnimation(
                .easeIn(duration: 0.3)
                .delay(Double(index) * 0.03 + 0.3)
            ) {
                particleOpacities[index] = 0
            }
        }
    }

    private func stopCelebration() {
        isAnimating = false
    }
}
