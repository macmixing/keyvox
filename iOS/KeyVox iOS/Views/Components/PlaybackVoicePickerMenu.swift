import SwiftUI

struct PlaybackVoicePickerMenu<Label: View>: View {
    let voices: [AppSettingsStore.TTSVoice]
    let selection: Binding<AppSettingsStore.TTSVoice>
    @ViewBuilder let label: () -> Label

    var body: some View {
        Menu {
            Picker("", selection: selection) {
                ForEach(voices) { voice in
                    Text(voice.displayName).tag(voice)
                }
            }
            .pickerStyle(.inline)
        } label: {
            label()
        }
        .buttonStyle(.plain)
    }
}
