import SwiftUI

extension SettingsView {
    private func isRecommendedMicrophone(_ microphone: MicrophoneOption) -> Bool {
        microphone.kind == .builtIn
    }

    var audioSettings: some View {
        VStack(alignment: .leading, spacing: 10) {
            Spacer().frame(height: 4)
            
            Text("CUSTOMIZE")
                .font(.custom("Kanit Medium", size: 10))
                .foregroundColor(.secondary.opacity(0.6))
                .padding(.leading, 4)
            
            SettingsCard {
                HStack(alignment: .top, spacing: 16) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color.indigo.opacity(0.15))
                            .frame(width: 44, height: 44)
                        Image(systemName: "mic.fill")
                            .font(.custom("Kanit Medium", size: 20))
                            .foregroundColor(.indigo)
                    }
                    
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Microphone Input")
                            .font(.custom("Kanit Medium", size: 17))
                        
                        Text(microphoneSubtitle)
                            .font(.custom("Kanit Medium", size: 12))
                            .foregroundColor(microphoneSubtitleColor)
                            .lineSpacing(2)
                            .fixedSize(horizontal: false, vertical: true)
                        
                        Picker("", selection: $audioDeviceManager.selectedMicrophoneUID) {
                            ForEach(audioDeviceManager.pickerMicrophones) { microphone in
                                Text(microphonePickerLabel(for: microphone))
                                    .tag(microphone.id)
                            }
                        }
                        .pickerStyle(.menu)
                        .labelsHidden()
                        .disabled(audioDeviceManager.pickerMicrophones.isEmpty)
                        .frame(maxWidth: .infinity)
                    }
                }
            }
            
            SettingsCard {
                HStack(alignment: .top, spacing: 16) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color.indigo.opacity(0.15))
                            .frame(width: 44, height: 44)
                        Image(systemName: "speaker.wave.2.fill")
                            .font(.custom("Kanit Medium", size: 20))
                            .foregroundColor(.indigo)
                    }

                    VStack(alignment: .leading, spacing: 12) {
                        HStack(alignment: .top, spacing: 16) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("System Sounds")
                                    .font(.custom("Kanit Medium", size: 17))

                                Text("Play audio feedback when recording starts and ends.")
                                    .font(.custom("Kanit Medium", size: 12))
                                    .foregroundColor(.secondary)
                                    .lineSpacing(2)
                                    .fixedSize(horizontal: false, vertical: true)
                            }

                            Spacer(minLength: 16)

                            Toggle("", isOn: $keyboardMonitor.isSoundEnabled)
                                .toggleStyle(SwitchToggleStyle(tint: .indigo))
                                .labelsHidden()
                        }

                        VStack(alignment: .leading, spacing: 6) {
                            Text("Adjust volume")
                                .font(.custom("Kanit Medium", size: 13))
                                .foregroundColor(.primary)

                            HStack(spacing: 12) {
                                Slider(value: $keyboardMonitor.soundVolume, in: 0...1)
                                    .tint(.indigo)
                                    .disabled(!keyboardMonitor.isSoundEnabled)

                                Text("\(Int((keyboardMonitor.soundVolume * 100).rounded()))%")
                                    .font(.custom("Kanit Medium", size: 12))
                                    .foregroundColor(.secondary)
                                    .frame(width: 40, alignment: .trailing)
                            }
                        }
                        .opacity(keyboardMonitor.isSoundEnabled ? 1 : 0.7)
                    }
                }
            }
        }
    }
    
    var microphoneSubtitle: String {
        guard let selected = audioDeviceManager.selectedMicrophone else {
            if !audioDeviceManager.selectedMicrophoneUID.isEmpty {
                return "Selected mic is unavailable. Built-in Microphone will be used until it reconnects."
            }
            return "Built-in Microphone is recommended for the fastest and most reliable dictation."
        }

        switch selected.kind {
        case .builtIn:
            if isRecommendedMicrophone(selected) {
                return "\(selected.name) selected. Recommended for fastest startup and best reliability."
            }
            return "\(selected.name) selected."
        case .airPods:
            return "\(selected.name) selected. Bluetooth mics may start slower and reduce dictation accuracy."
        case .bluetooth:
            return "\(selected.name) selected. Startup can be slower before dictation begins."
        case .wiredOrOther:
            return "\(selected.name) selected. Built-in Microphone is still recommended for best speed."
        }
    }

    var microphoneSubtitleColor: Color {
        guard let selected = audioDeviceManager.selectedMicrophone else {
            return .secondary
        }

        switch selected.kind {
        case .airPods, .bluetooth:
            return .yellow
        case .builtIn, .wiredOrOther:
            return .secondary
        }
    }

    func microphonePickerLabel(for microphone: MicrophoneOption) -> String {
        if !microphone.isAvailable {
            return "Previously Selected Microphone (Unavailable)"
        }

        if isRecommendedMicrophone(microphone) {
            return "\(microphone.name) (Recommended)"
        }

        return microphone.name
    }
}
