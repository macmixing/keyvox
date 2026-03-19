import SwiftUI

struct OnboardingStepRow<ExtraContent: View, TrailingContent: View>: View {
    let isCompleted: Bool
    let stepNumber: Int
    let title: String
    let description: String
    let buttonTitle: String?
    let isButtonEnabled: Bool
    let action: (() -> Void)?
    let extraContent: ExtraContent
    let trailingContent: TrailingContent
    @State private var displayedButtonTitle: String?
    @State private var showsButtonSlot: Bool
    @State private var isButtonVisible: Bool
    @State private var buttonCollapseTask: Task<Void, Never>?

    init(
        isCompleted: Bool,
        stepNumber: Int,
        title: String,
        description: String,
        buttonTitle: String?,
        isButtonEnabled: Bool = true,
        action: (() -> Void)?,
        @ViewBuilder trailingContent: () -> TrailingContent = { EmptyView() },
        @ViewBuilder extraContent: () -> ExtraContent = { EmptyView() }
    ) {
        self.isCompleted = isCompleted
        self.stepNumber = stepNumber
        self.title = title
        self.description = description
        self.buttonTitle = buttonTitle
        self.isButtonEnabled = isButtonEnabled
        self.action = action
        self.trailingContent = trailingContent()
        self.extraContent = extraContent()
        _displayedButtonTitle = State(initialValue: buttonTitle)
        _showsButtonSlot = State(initialValue: buttonTitle != nil)
        _isButtonVisible = State(initialValue: buttonTitle != nil)
    }

    var body: some View {
        AppCard {
            VStack(alignment: .leading, spacing: 16) {
                HStack(alignment: .center, spacing: 12) {
                    stepIndicator
                    titleView
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                
                VStack(alignment: .leading, spacing: 12) {
                    HStack(alignment: .firstTextBaseline, spacing: 8) {
                        Text(description)
                            .font(.appFont(15, variant: .light))
                            .foregroundStyle(.white.opacity(0.85))
                            .frame(maxWidth: .infinity, alignment: .leading)
                        
                        trailingContent
                    }
                    
                    if extraContent is EmptyView == false {
                        extraContent
                    }
                    
                    if showsButtonSlot {
                        buttonView
                            .frame(maxWidth: .infinity, alignment: .trailing)
                    }
                }
            }
        }
        .onChange(of: buttonTitle, initial: false) { _, newValue in
            updateButtonPresentation(for: newValue)
        }
        .onDisappear {
            buttonCollapseTask?.cancel()
        }
    }

    private var stepIndicator: some View {
        ZStack {
            Circle()
                .fill(isCompleted ? Color.green : AppTheme.accent.opacity(0.4))
                .frame(width: 32, height: 32)

            if isCompleted {
                Image(systemName: "checkmark")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(.white)
            } else {
                Text("\(stepNumber)")
                    .font(.appFont(16))
                    .foregroundColor(.white)
            }
        }
    }

    private var titleView: some View {
        Text(title)
            .font(.appFont(18))
            .foregroundStyle(.white)
            .multilineTextAlignment(.leading)
            .fixedSize(horizontal: false, vertical: true)
            .layoutPriority(1)
    }

    @ViewBuilder
    private var buttonView: some View {
        if let displayedButtonTitle {
            AppActionButton(
                title: displayedButtonTitle,
                style: .primary,
                size: .compact,
                fontSize: 15,
                isEnabled: isButtonEnabled,
                action: action ?? {}
            )
            .fixedSize(horizontal: true, vertical: false)
            .opacity(isButtonVisible ? 1 : 0)
            .allowsHitTesting(isButtonVisible)
            .accessibilityHidden(!isButtonVisible)
        }
    }

    private var buttonFadeAnimation: Animation {
        .easeOut(duration: buttonFadeDuration)
    }

    private var rowResizeAnimation: Animation {
        .easeInOut(duration: rowResizeDuration)
    }

    private var buttonFadeDuration: Double {
        0.14
    }

    private var rowResizeDuration: Double {
        0.52
    }

    private var rowResizeDelay: Double {
        0.1
    }

    private var buttonRemovalDelay: UInt64 {
        UInt64((buttonFadeDuration + rowResizeDelay) * 1_000_000_000)
    }

    private var buttonCleanupDelay: UInt64 {
        UInt64(rowResizeDuration * 1_000_000_000)
    }

    private func updateButtonPresentation(for newValue: String?) {
        buttonCollapseTask?.cancel()

        if let newValue {
            displayedButtonTitle = newValue

            if showsButtonSlot == false {
                showsButtonSlot = true
            }

            withAnimation(buttonFadeAnimation) {
                isButtonVisible = true
            }
            return
        }

        guard showsButtonSlot else {
            displayedButtonTitle = nil
            return
        }

        withAnimation(buttonFadeAnimation) {
            isButtonVisible = false
        }

        buttonCollapseTask = Task { @MainActor in
            try? await Task.sleep(nanoseconds: buttonRemovalDelay)

            guard Task.isCancelled == false else { return }

            withAnimation(rowResizeAnimation) {
                showsButtonSlot = false
            }

            try? await Task.sleep(nanoseconds: buttonCleanupDelay)

            guard Task.isCancelled == false else { return }

            displayedButtonTitle = nil
        }
    }

}

#Preview {
    VStack(spacing: 12) {
        OnboardingStepRow(
            isCompleted: false,
            stepNumber: 1,
            title: "AI Model Setup",
            description: "OpenAI Whisper Base (~190 MB)",
            buttonTitle: "Download Now",
            action: {},
            trailingContent: {
                Text("45%")
                    .font(.appFont(11))
                    .foregroundStyle(.yellow)
            },
            extraContent: {
                ModelDownloadProgress(progress: 0.45, showLabel: false)
            }
        )

        OnboardingStepRow(
            isCompleted: true,
            stepNumber: 2,
            title: "Microphone Access",
            description: "KeyVox needs to hear you to transcribe.",
            buttonTitle: nil,
            action: nil
        )

        OnboardingStepRow(
            isCompleted: false,
            stepNumber: 3,
            title: "Enable Keyboard",
            description: "Allow Full Access in Settings.",
            buttonTitle: "Open Settings",
            action: {}
        )
    }
    .padding()
    .background(AppTheme.screenBackground)
}
