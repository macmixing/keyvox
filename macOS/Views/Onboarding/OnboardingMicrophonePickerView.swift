import Foundation
import SwiftUI

struct OnboardingMicrophonePickerView: View {
    private enum Layout {
        static let actionButtonWidth: CGFloat = 150
    }

    @Binding var selectedMicrophoneUID: String
    let microphones: [MicrophoneOption]
    let onConfirm: @MainActor () -> Void

    private var canConfirmSelection: Bool {
        !selectedMicrophoneUID.isEmpty && !microphones.isEmpty
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 8) {
                Text("Choose Your Microphone", comment: "Title of the microphone picker shown during onboarding.")
                    .font(.appFont(19))
                    .foregroundColor(.white)

                if microphones.isEmpty {
                    Text("No microphone detected. Connect one to continue onboarding.", comment: "Message in the onboarding microphone picker when no microphone is connected.")
                        .font(.appFont(12, variant: .light))
                        .foregroundColor(.secondary)
                        .lineSpacing(2)
                } else {
                    Text("No built-in microphone was found. Select a default microphone to continue.", comment: "Message in the onboarding microphone picker when the Mac has no built-in microphone.")
                        .font(.appFont(12, variant: .light))
                        .foregroundColor(.secondary)
                        .lineSpacing(2)
                }
            }

            Picker(String(localized: "Microphone", comment: "Hidden label of the microphone picker during onboarding, read by VoiceOver."), selection: $selectedMicrophoneUID) {
                ForEach(microphones) { microphone in
                    Text(microphone.name).tag(microphone.id)
                }
            }
            .pickerStyle(.menu)
            .labelsHidden()
            .frame(maxWidth: .infinity)
            .disabled(microphones.isEmpty)

            HStack {
                AppActionButton(
                    title: String(localized: "Use Microphone", comment: "Button in the onboarding microphone picker that confirms the selected microphone."),
                    style: .primary,
                    minWidth: Layout.actionButtonWidth,
                    isEnabled: canConfirmSelection,
                    action: onConfirm
                )
            }
            .frame(maxWidth: .infinity, alignment: .center)
        }
        .padding(18)
        .frame(maxWidth: .infinity, minHeight: 205)
        .background(
            ZStack {
                VisualEffectView(material: .menu, blendingMode: .behindWindow)
                MacAppTheme.screenBackground
            }
        )
        .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .stroke(MacAppTheme.windowStroke, lineWidth: 0.7)
        )
        .preferredColorScheme(.dark)
    }
}
