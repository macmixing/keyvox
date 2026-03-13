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
                Text("Choose Your Microphone")
                    .font(.appFont(19))
                    .foregroundColor(.white)

                if microphones.isEmpty {
                    Text("No microphone detected. Connect one to continue onboarding.")
                        .font(.appFont(12))
                        .foregroundColor(.secondary)
                        .lineSpacing(2)
                } else {
                    Text("No built-in microphone was found. Select a default microphone to continue.")
                        .font(.appFont(12))
                        .foregroundColor(.secondary)
                        .lineSpacing(2)
                }
            }

            Picker("Microphone", selection: $selectedMicrophoneUID) {
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
                    title: "Use Microphone",
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
