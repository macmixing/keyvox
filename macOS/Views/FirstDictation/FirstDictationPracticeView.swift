import SwiftUI

struct FirstDictationPracticeView: View {
    @ObservedObject private var keyboardMonitor = KeyboardMonitor.shared
    @Binding var text: String
    @FocusState.Binding var isTextFieldFocused: Bool
    let hasSucceeded: Bool
    let onFinish: () -> Void
    let onEscape: () -> Void

    @State private var isEscapeVisible = false

    private enum Layout {
        static let horizontalPadding: CGFloat = 34
        static let inputHorizontalInset: CGFloat = 40
        static let inputBottomPadding: CGFloat = 28
        static let inputHeight: CGFloat = 68
        static let finishButtonReservedHeight: CGFloat = 72
        static let actionWidth: CGFloat = 118
        static let escapeDelay: Duration = .seconds(90)
        static let escapeFadeDuration: TimeInterval = 0.2
    }

    var body: some View {
        GeometryReader { geometry in
            MacAppTheme.screenBackground
                .overlay(alignment: .topTrailing) {
                    action
                        .padding(.top, 24)
                        .padding(.trailing, 24)
                }
                .overlay(alignment: .top) {
                    centerContent
                        .frame(maxWidth: .infinity)
                        .frame(
                            height: centerContentAreaHeight(for: geometry.size.height),
                            alignment: .center
                        )
                        .padding(.top, centerContentTopInset)
                        .padding(.horizontal, Layout.horizontalPadding)
                }
                .overlay(alignment: .bottom) {
                    inputBar
                        .frame(width: max(0, geometry.size.width - Layout.inputHorizontalInset))
                        .padding(.bottom, Layout.inputBottomPadding)
                }
        }
        .onAppear {
            isTextFieldFocused = true
        }
        .task(id: hasSucceeded) {
            guard hasSucceeded == false else { return }

            do {
                try await Task.sleep(for: Layout.escapeDelay)
            } catch {
                return
            }

            guard Task.isCancelled == false, hasSucceeded == false else { return }
            withAnimation(.easeInOut(duration: Layout.escapeFadeDuration)) {
                isEscapeVisible = true
            }
        }
    }

    @ViewBuilder
    private var action: some View {
        if hasSucceeded {
            AppActionButton(
                title: "Finish",
                style: .primary,
                minWidth: Layout.actionWidth,
                action: onFinish
            )
        } else if isEscapeVisible {
            Button(action: onEscape) {
                Image(systemName: "xmark")
                    .font(.system(size: 15, weight: .medium))
                    .foregroundColor(.white.opacity(0.5))
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Exit dictation practice")
            .transition(.opacity)
        }
    }

    private var centerContentTopInset: CGFloat {
        hasSucceeded ? Layout.finishButtonReservedHeight : 0
    }

    private var centerContentBottomInset: CGFloat {
        Layout.inputBottomPadding + Layout.inputHeight
    }

    private func centerContentAreaHeight(for height: CGFloat) -> CGFloat {
        max(0, height - centerContentTopInset - centerContentBottomInset)
    }

    @ViewBuilder
    private var centerContent: some View {
        if hasSucceeded {
            FirstDictationSuccessCelebrationView()
        } else {
            VStack(spacing: 12) {
                Text("Hold the \(keyboardMonitor.triggerBinding.practiceInstructionKeyName) key and talk.")
                    .font(.appFont(20, variant: .medium))
                    .foregroundColor(.white)
                    .multilineTextAlignment(.center)

                FirstDictationOptionKeyPromptView()

                Text("Release when you're done.")
                    .font(.appFont(18, variant: .medium))
                    .foregroundColor(.white.opacity(0.82))
                    .multilineTextAlignment(.center)
                    .padding(.top, 10)
                    
                Text("You can change this key later in Settings.")
                    .font(.appFont(12, variant: .light))
                    .foregroundColor(.yellow.opacity(0.5))
                    .multilineTextAlignment(.center)
            }
        }
    }

    private var inputBar: some View {
        TextField("", text: $text)
            .textFieldStyle(.plain)
            .font(.appFont(16, variant: .light))
            .foregroundColor(.white)
            .focused($isTextFieldFocused)
            .frame(maxWidth: .infinity)
            .frame(height: 40)
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(MacAppTheme.cardFill)
                    .overlay(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .stroke(MacAppTheme.cardStroke, lineWidth: 1)
                    )
            )
    }
}

private extension AppSettingsStore.TriggerBinding {
    var practiceInstructionKeyName: String {
        switch self {
        case .leftOption:
            return "Left Option"
        case .rightOption:
            return "Right Option"
        case .leftCommand:
            return "Left Command"
        case .rightCommand:
            return "Right Command"
        case .leftControl:
            return "Left Control"
        case .rightControl:
            return "Right Control"
        case .function:
            return "Function"
        }
    }
}
