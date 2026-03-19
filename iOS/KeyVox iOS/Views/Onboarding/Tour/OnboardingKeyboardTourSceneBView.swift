import SwiftUI

struct OnboardingKeyboardTourSceneBView: View {
    private enum Metrics {
        static let contentOffset: CGFloat = 10
    }

    @State private var isInstructionVisible = false
    @State private var instructionRevealTask: Task<Void, Never>?

    var body: some View {
        VStack(spacing: 16) {
            Text("Tap the microphone & speak.")
                .font(.appFont(18, variant: .light))
                .foregroundStyle(.white)
                .multilineTextAlignment(.center)
                .opacity(isInstructionVisible ? 1 : 0)
                .padding(.bottom, 18)

            OnboardingLogoPopInSequence(size: 100, delay: 0.5)

            Text("Tap again to transcribe.")
                .font(.appFont(18, variant: .light))
                .foregroundStyle(.white)
                .multilineTextAlignment(.center)
                .opacity(isInstructionVisible ? 1 : 0)
                .padding(.top, 18)
        }
        .offset(y: Metrics.contentOffset)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onAppear {
            startInstructionReveal()
        }
        .onDisappear {
            stopInstructionReveal()
        }
    }

    private func startInstructionReveal() {
        stopInstructionReveal()
        isInstructionVisible = false

        instructionRevealTask = Task { @MainActor in
            try? await Task.sleep(for: .seconds(0.5))
            guard Task.isCancelled == false else { return }

            withAnimation(.easeInOut(duration: 0.35)) {
                isInstructionVisible = true
            }
        }
    }

    private func stopInstructionReveal() {
        instructionRevealTask?.cancel()
        instructionRevealTask = nil
        isInstructionVisible = false
    }
}
