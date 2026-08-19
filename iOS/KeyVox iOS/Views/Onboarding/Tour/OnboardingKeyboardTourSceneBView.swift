import SwiftUI
import UIKit

struct OnboardingKeyboardTourSceneBView: View {
    private enum Metrics {
        static let contentOffset: CGFloat = 10
        static let preferredInstructionFontSize: CGFloat = 21
        static let fallbackInstructionFontSize: CGFloat = 17
        static let iPhoneMinimumInstructionGap: CGFloat = 20
        static let iPadMinimumInstructionGap: CGFloat = 5
        static let maximumInstructionGap: CGFloat = 34
    }

    @State private var isInstructionVisible = false
    @State private var instructionRevealTask: Task<Void, Never>?

    private var minimumInstructionGap: CGFloat {
        UIDevice.current.model == "iPad"
            ? Metrics.iPadMinimumInstructionGap
            : Metrics.iPhoneMinimumInstructionGap
    }

    var body: some View {
        ViewThatFits(in: .horizontal) {
            sceneContent(fontSize: Metrics.preferredInstructionFontSize)
            sceneContent(fontSize: Metrics.fallbackInstructionFontSize)
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

    private func sceneContent(fontSize: CGFloat) -> some View {
        VStack(spacing: 0) {
            Text("Tap the microphone & speak.")
                .font(.appFont(fontSize, variant: .light))
                .foregroundStyle(.white)
                .multilineTextAlignment(.center)
                .lineLimit(1)
                .fixedSize(horizontal: true, vertical: true)
                .opacity(isInstructionVisible ? 1 : 0)

            Spacer(minLength: minimumInstructionGap)
                .frame(maxHeight: Metrics.maximumInstructionGap)

            OnboardingLogoPopInSequence(size: 90, delay: 0.5)

            Spacer(minLength: minimumInstructionGap)
                .frame(maxHeight: Metrics.maximumInstructionGap)

            Text("Tap again to transcribe.")
                .font(.appFont(fontSize, variant: .light))
                .foregroundStyle(.white)
                .multilineTextAlignment(.center)
                .lineLimit(1)
                .fixedSize(horizontal: true, vertical: true)
                .opacity(isInstructionVisible ? 1 : 0)
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
