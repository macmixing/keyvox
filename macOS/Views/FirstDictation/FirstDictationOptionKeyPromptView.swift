import SwiftUI

struct FirstDictationOptionKeyPromptView: View {
    @ObservedObject private var keyboardMonitor = KeyboardMonitor.shared
    @State private var isPromptPressed = false

    var body: some View {
        let isKeyDown = keyboardMonitor.isTriggerKeyPressed || isPromptPressed
        let triggerBinding = keyboardMonitor.triggerBinding

        keycapContent(for: triggerBinding)
            .foregroundColor(.white)
            .padding(10)
            .frame(width: 72, height: 72)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(Color.white.opacity(isKeyDown ? 0.12 : 0.07))
                    .overlay(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .stroke(Color.yellow.opacity(isKeyDown ? 0.9 : 0.28), lineWidth: 2)
                    )
            )
            .shadow(color: .yellow.opacity(isKeyDown ? 0.35 : 0.08), radius: isKeyDown ? 16 : 6)
            .scaleEffect(isKeyDown ? 0.94 : 1)
            .offset(y: isKeyDown ? 8 : 0)
            .animation(.easeInOut(duration: 0.12), value: keyboardMonitor.isTriggerKeyPressed)
            .task(id: keyboardMonitor.isTriggerKeyPressed) {
                if keyboardMonitor.isTriggerKeyPressed {
                    resetPromptAnimation()
                    return
                }

                await runPromptAnimation()
            }
    }

    @ViewBuilder
    private func keycapContent(for triggerBinding: AppSettingsStore.TriggerBinding) -> some View {
        if triggerBinding == .function {
            functionKeycapContent
        } else {
            modifierKeycapContent(for: triggerBinding)
        }
    }

    private var functionKeycapContent: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("fn")
                .font(.system(size: 19, weight: .semibold))
                .frame(maxWidth: .infinity, alignment: .trailing)

            Spacer(minLength: 0)

            Image(systemName: "globe")
                .font(.system(size: 17, weight: .semibold))
                .symbolRenderingMode(.monochrome)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private func modifierKeycapContent(for triggerBinding: AppSettingsStore.TriggerBinding) -> some View {
        VStack(alignment: triggerBinding.keycapHorizontalAlignment, spacing: 0) {
            Image(systemName: triggerBinding.keycapSystemImageName)
                .font(.system(size: 22, weight: .semibold))
                .symbolRenderingMode(.monochrome)
                .frame(maxWidth: .infinity, alignment: triggerBinding.keycapAlignment)

            Spacer(minLength: 0)

            Text(triggerBinding.keycapTitle)
                .font(.appFont(16))
                .minimumScaleFactor(0.72)
                .lineLimit(1)
                .frame(maxWidth: .infinity, alignment: triggerBinding.keycapAlignment)
        }
    }

    @MainActor
    private func resetPromptAnimation() {
        var transaction = Transaction()
        transaction.disablesAnimations = true
        withTransaction(transaction) {
            isPromptPressed = false
        }
    }

    @MainActor
    private func runPromptAnimation() async {
        resetPromptAnimation()

        while Task.isCancelled == false {
            try? await Task.sleep(for: .milliseconds(120))
            guard Task.isCancelled == false else { return }
            withAnimation(.easeInOut(duration: 0.72)) {
                isPromptPressed = true
            }
            try? await Task.sleep(for: .milliseconds(720))
            guard Task.isCancelled == false else { return }
            withAnimation(.easeInOut(duration: 0.72)) {
                isPromptPressed = false
            }
            try? await Task.sleep(for: .milliseconds(720))
        }
    }
}

private extension AppSettingsStore.TriggerBinding {
    var keycapAlignment: Alignment {
        switch self {
        case .leftOption, .leftCommand, .leftControl:
            return .trailing
        case .rightOption, .rightCommand, .rightControl, .function:
            return .leading
        }
    }

    var keycapHorizontalAlignment: HorizontalAlignment {
        switch self {
        case .leftOption, .leftCommand, .leftControl:
            return .trailing
        case .rightOption, .rightCommand, .rightControl, .function:
            return .leading
        }
    }

    var keycapSystemImageName: String {
        switch self {
        case .leftOption, .rightOption:
            return "option"
        case .leftCommand, .rightCommand:
            return "command"
        case .leftControl, .rightControl:
            return "control"
        case .function:
            return "globe"
        }
    }

    var keycapTitle: String {
        switch self {
        case .leftOption, .rightOption:
            return "option"
        case .leftCommand, .rightCommand:
            return "command"
        case .leftControl, .rightControl:
            return "control"
        case .function:
            return "function"
        }
    }
}
