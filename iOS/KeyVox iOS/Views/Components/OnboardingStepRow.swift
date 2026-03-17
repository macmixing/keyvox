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
    }

    var body: some View {
        AppCard {
            VStack(alignment: .leading, spacing: 12) {
                // Top row: Step circle + Title + Button
                HStack(alignment: .center, spacing: 12) {
                    // Step Number Circle
                    ZStack {
                        Circle()
                            .fill(isCompleted ? Color.green : AppTheme.accent.opacity(0.2))
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

                    Text(title)
                        .font(.appFont(18))
                        .foregroundStyle(.white)
                    
                    Spacer()

                    if let buttonTitle {
                        AppActionButton(
                            title: buttonTitle,
                            style: .primary,
                            size: .compact,
                            fontSize: 15,
                            isEnabled: isButtonEnabled,
                            action: action ?? {}
                        )
                    }
                }
                
                // Description row - full width with proper leading padding
                HStack(spacing: 0) {
                    // Align with title text (circle width + spacing)
                    Spacer()
                        .frame(width: 44)
                    
                    HStack(alignment: .firstTextBaseline, spacing: 8) {
                        Text(description)
                            .font(.appFont(14, variant: .light))
                            .foregroundStyle(.white.opacity(0.8))
                            .frame(maxWidth: .infinity, alignment: .leading)
                        
                        trailingContent
                    }
                }
                
                // Extra content (like download progress) - full width with padding
                if extraContent is EmptyView == false {
                    HStack(spacing: 0) {
                        Spacer()
                            .frame(width: 44)
                        
                        extraContent
                    }
                }
            }
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
