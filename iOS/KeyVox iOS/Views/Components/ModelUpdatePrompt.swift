import SwiftUI

enum PendingModelUpdatePrompt: Identifiable, Equatable {
    case parakeetArtifactUpdate

    var id: String {
        switch self {
        case .parakeetArtifactUpdate:
            return "parakeet-artifact-update"
        }
    }

    var title: String {
        switch self {
        case .parakeetArtifactUpdate:
            return "Parakeet Update Required"
        }
    }

    var message: String {
        switch self {
        case .parakeetArtifactUpdate:
            return "Sorry about this, but Parakeet dictation will not work on iOS 27 until this model update is installed. Download the updated Parakeet model now (~335 MB), or do it later from Settings."
        }
    }
}

extension View {
    func modelUpdatePrompt(
        _ prompt: Binding<PendingModelUpdatePrompt?>,
        onDownload: @escaping (PendingModelUpdatePrompt) -> Void
    ) -> some View {
        modifier(
            ModelUpdatePromptModifier(
                prompt: prompt,
                onDownload: onDownload
            )
        )
    }
}

private struct ModelUpdatePromptModifier: ViewModifier {
    @Binding var prompt: PendingModelUpdatePrompt?
    let onDownload: (PendingModelUpdatePrompt) -> Void
    @AccessibilityFocusState private var isLaterFocused: Bool

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
                            Text(prompt.title)
                                .font(.appFont(22))
                                .foregroundStyle(.white)

                            Text(prompt.message)
                                .font(.appFont(15, variant: .light))
                                .foregroundStyle(.white.opacity(0.78))

                            HStack(spacing: 12) {
                                AppActionButton(
                                    title: "Later",
                                    style: .secondary,
                                    fillsWidth: true,
                                    size: .regular,
                                    fontSize: 16,
                                    action: {
                                        self.prompt = nil
                                    }
                                )
                                .accessibilityFocused($isLaterFocused)

                                AppActionButton(
                                    title: "Download",
                                    style: .primary,
                                    fillsWidth: true,
                                    size: .regular,
                                    fontSize: 16,
                                    action: {
                                        let activePrompt = prompt
                                        self.prompt = nil
                                        onDownload(activePrompt)
                                    }
                                )
                            }
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
                        isLaterFocused = true
                    }
                }
            }
            .animation(.easeInOut(duration: 0.18), value: prompt != nil)
            .onChange(of: prompt) { oldValue, newValue in
                if oldValue != nil, newValue != nil, oldValue != newValue {
                    isLaterFocused = true
                }
            }
    }
}
