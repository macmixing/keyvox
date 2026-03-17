import SwiftUI

struct OnboardingLogoPopInSequence: View {
    let size: CGFloat
    let delay: Double
    var onRevealStarted: (() -> Void)? = nil

    @State private var scale: CGFloat = 0.12
    @State private var opacity: Double = 0
    @State private var sequenceTask: Task<Void, Never>?

    var body: some View {
        LogoBarView(size: size)
            .scaleEffect(scale)
            .opacity(opacity)
            .onAppear {
                startSequence()
            }
            .onDisappear {
                stopSequence()
            }
    }

    private func startSequence() {
        stopSequence()
        scale = 0.12
        opacity = 0

        sequenceTask = Task { @MainActor in
            try? await Task.sleep(for: .seconds(delay))
            guard Task.isCancelled == false else { return }

            opacity = 1
            onRevealStarted?()

            withAnimation(.easeOut(duration: 0.15)) {
                scale = 0.92
            }

            try? await Task.sleep(for: .seconds(0.2))
            guard Task.isCancelled == false else { return }

            withAnimation(.easeOut(duration: 0.2)) {
                scale = 1.16
            }

            try? await Task.sleep(for: .seconds(0.05))
            guard Task.isCancelled == false else { return }

            withAnimation(.easeInOut(duration: 0.3)) {
                scale = 1.0
            }
        }
    }

    private func stopSequence() {
        sequenceTask?.cancel()
        sequenceTask = nil
    }
}
