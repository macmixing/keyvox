import SwiftUI

extension View {
    func appUpdatePrompt(
        _ prompt: AppUpdateCoordinator.Prompt?,
        onUpdate: @escaping () -> Void,
        onLater: @escaping () -> Void
    ) -> some View {
        modifier(
            AppUpdatePromptModifier(
                prompt: prompt,
                onUpdate: onUpdate,
                onLater: onLater
            )
        )
    }
}

private struct AppUpdatePromptModifier: ViewModifier {
    let prompt: AppUpdateCoordinator.Prompt?
    let onUpdate: () -> Void
    let onLater: () -> Void
    @AccessibilityFocusState private var isPrimaryActionFocused: Bool

    func body(content: Content) -> some View {
        content
            .accessibilityHidden(prompt != nil)
            .overlay {
                if let prompt {
                    ZStack {
                        Color.black.opacity(0.6)
                            .ignoresSafeArea()
                            .contentShape(Rectangle())

                        VStack(alignment: .leading, spacing: 18) {
                            Text(title(for: prompt))
                                .font(.appFont(22))
                                .foregroundStyle(.white)

                            Text(message(for: prompt))
                                .font(.appFont(15, variant: .light))
                                .foregroundStyle(.white.opacity(0.78))

                            actionButtons(for: prompt)
                        }
                        .padding(22)
                        .frame(maxWidth: 420, alignment: .leading)
                        .background(AppTheme.screenBackground)
                        .overlay {
                            RoundedRectangle(cornerRadius: 28, style: .continuous)
                                .stroke(Color.yellow.opacity(0.9), lineWidth: 1.5)
                        }
                        .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
                        .shadow(color: .black.opacity(0.25), radius: 26, y: 12)
                        .padding(.horizontal, 24)
                    }
                    .accessibility(addTraits: .isModal)
                    .transition(.opacity)
                    .zIndex(10)
                    .onAppear {
                        isPrimaryActionFocused = true
                    }
                }
            }
            .animation(.easeInOut(duration: 0.18), value: prompt != nil)
            .onChange(of: prompt?.id) { oldValue, newValue in
                if oldValue != nil, newValue != nil, oldValue != newValue {
                    isPrimaryActionFocused = true
                }
            }
    }

    @ViewBuilder
    private func actionButtons(for prompt: AppUpdateCoordinator.Prompt) -> some View {
        switch prompt.decision.urgency {
        case .optional:
            HStack(spacing: 12) {
                AppActionButton(
                    title: "Later",
                    style: .secondary,
                    fillsWidth: true,
                    size: .regular,
                    fontSize: 16,
                    action: onLater
                )

                updateButton
            }
        case .forced:
            updateButton
        }
    }

    private var updateButton: some View {
        AppActionButton(
            title: "Update",
            style: .primary,
            fillsWidth: true,
            size: .regular,
            fontSize: 16,
            action: onUpdate
        )
        .accessibilityFocused($isPrimaryActionFocused)
    }

    private func title(for prompt: AppUpdateCoordinator.Prompt) -> String {
        switch prompt.decision.urgency {
        case .optional:
            return "Update Available"
        case .forced:
            return "Update Required"
        }
    }

    private func message(for prompt: AppUpdateCoordinator.Prompt) -> String {
        switch prompt.decision.urgency {
        case .optional:
            return "KeyVox \(prompt.decision.release.version.rawValue) is available on the App Store."
        case .forced:
            return "KeyVox \(prompt.decision.release.version.rawValue) is required to continue using the app."
        }
    }
}
