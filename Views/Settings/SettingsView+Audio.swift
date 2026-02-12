import SwiftUI

extension SettingsView {
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
                            .foregroundColor(.secondary)
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
                SettingsRow(
                    icon: "speaker.wave.2.fill",
                    title: "System Sounds",
                    subtitle: "Play audio feedback when recording starts and ends."
                ) {
                    Toggle("", isOn: $keyboardMonitor.isSoundEnabled)
                        .toggleStyle(SwitchToggleStyle(tint: .indigo))
                        .labelsHidden()
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
            return "Built-in Microphone selected. Recommended for fastest startup and best reliability."
        case .airPods:
            return "AirPods selected. Bluetooth mics may start slower and reduce dictation accuracy."
        case .bluetooth:
            return "Bluetooth microphone selected. Startup can be slower before dictation begins."
        case .wiredOrOther:
            return "External microphone selected. Built-in Microphone is still recommended for best speed."
        }
    }

    func microphonePickerLabel(for microphone: MicrophoneOption) -> String {
        if !microphone.isAvailable {
            return "Previously Selected Microphone (Unavailable)"
        }

        if microphone.kind == .builtIn {
            return "\(microphone.name) (Recommended)"
        }

        return microphone.name
    }
}
