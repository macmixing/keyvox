import SwiftUI

struct OnboardingMicrophonePickerView: View {
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
                Spacer()

                Button("Use Microphone") {
                    onConfirm()
                }
                .buttonStyle(.borderedProminent)
                .tint(.indigo)
                .controlSize(.regular)
                .disabled(!canConfirmSelection)
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, minHeight: 205)
        .background(
            ZStack {
                VisualEffectView(material: .menu, blendingMode: .behindWindow)
                Color.indigo.opacity(0.15)
                    .background(Color(white: 0.01))
            }
        )
        .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .stroke(Color.white.opacity(0.12), lineWidth: 0.7)
        )
        .preferredColorScheme(.dark)
    }
}
