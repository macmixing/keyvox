import SwiftUI
import AppKit

private extension VerticalAlignment {
    private struct AudioHeaderCenterAlignment: AlignmentID {
        static func defaultValue(in dimensions: ViewDimensions) -> CGFloat {
            dimensions[VerticalAlignment.center]
        }
    }

    static let audioHeaderCenter = VerticalAlignment(AudioHeaderCenterAlignment.self)
}

extension SettingsView {
    private func isRecommendedMicrophone(_ microphone: MicrophoneOption) -> Bool {
        microphone.kind == .builtIn
    }

    var audioSettings: some View {
        VStack(alignment: .leading, spacing: 10) {
            Spacer().frame(height: 4)
            
            Text("MICROPHONE")
                .font(.appFont(10))
                .foregroundColor(.secondary.opacity(0.6))
                .padding(.leading, 4)
            
            SettingsCard {
                VStack(alignment: .leading, spacing: 12) {
                    HStack(alignment: .audioHeaderCenter, spacing: 16) {
                        ZStack {
                            RoundedRectangle(cornerRadius: 12)
                                .fill(Color.indigo.opacity(0.15))
                                .frame(width: 44, height: 44)
                            Image(systemName: "mic.fill")
                                .font(.appFont(20))
                                .foregroundColor(.indigo)
                        }
                        .alignmentGuide(.audioHeaderCenter) { dimensions in
                            dimensions[VerticalAlignment.center]
                        }
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Microphone Input")
                                .font(.appFont(17))
                            
                            Text(microphoneSubtitle)
                                .font(.appFont(12))
                                .foregroundColor(microphoneSubtitleColor)
                                .lineSpacing(2)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        .alignmentGuide(.audioHeaderCenter) { dimensions in
                            dimensions[VerticalAlignment.center]
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)

                    Picker("", selection: $appSettings.selectedMicrophoneUID) {
                        ForEach(audioDeviceManager.pickerMicrophones) { microphone in
                            Text(microphonePickerLabel(for: microphone))
                                .tag(microphone.id)
                        }
                    }
                    .pickerStyle(.menu)
                    .labelsHidden()
                    .disabled(audioDeviceManager.pickerMicrophones.isEmpty)
                    .fixedSize()
                    .frame(maxWidth: .infinity, alignment: .center)
                }
            }

            Text("SOUNDS")
                .font(.appFont(10))
                .foregroundColor(.secondary.opacity(0.6))
                .padding(.leading, 4)
            
            SettingsCard {
                HStack(alignment: .audioHeaderCenter, spacing: 16) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color.indigo.opacity(0.15))
                            .frame(width: 44, height: 44)
                        Image(systemName: "speaker.wave.2.fill")
                            .font(.appFont(20))
                            .foregroundColor(.indigo)
                    }
                    .alignmentGuide(.audioHeaderCenter) { dimensions in
                        dimensions[VerticalAlignment.center]
                    }

                    VStack(alignment: .leading, spacing: 12) {
                        HStack(alignment: .top, spacing: 16) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("System Sounds")
                                    .font(.appFont(17))

                                Text("Play audio feedback when recording starts and ends.")
                                    .font(.appFont(12))
                                    .foregroundColor(.secondary)
                                    .lineSpacing(2)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                            .alignmentGuide(.audioHeaderCenter) { dimensions in
                                dimensions[VerticalAlignment.center]
                            }

                            Spacer(minLength: 16)

                            Toggle("", isOn: $appSettings.isSoundEnabled)
                                .toggleStyle(SwitchToggleStyle(tint: .indigo))
                                .labelsHidden()
                        }

                        VStack(alignment: .leading, spacing: 6) {
                            Text("Adjust volume")
                                .font(.appFont(13))
                                .foregroundColor(.primary)

                            HStack(spacing: 12) {
                                Slider(
                                    value: $appSettings.soundVolume,
                                    in: 0...1,
                                    onEditingChanged: { isEditing in
                                        guard !isEditing else { return }
                                        playStartSoundPreview()
                                    }
                                )
                                    .tint(.indigo)
                                    .disabled(!appSettings.isSoundEnabled)

                                Text("\(Int((appSettings.soundVolume * 100).rounded()))%")
                                    .font(.appFont(12))
                                    .foregroundColor(.secondary)
                                    .frame(width: 40, alignment: .trailing)
                            }
                        }
                        .opacity(appSettings.isSoundEnabled ? 1 : 0.7)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
    }
    
    var microphoneSubtitle: String {
        guard let selected = audioDeviceManager.selectedMicrophone else {
            if !appSettings.selectedMicrophoneUID.isEmpty {
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
            return "\(selected.name) selected. This microphone may start slower and reduce dictation accuracy."
        case .bluetooth:
            return "\(selected.name) selected. Bluetooth devices may start slower and reduce dictation accuracy."
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

    private func playStartSoundPreview() {
        guard appSettings.isSoundEnabled else { return }
        guard let sound = NSSound(named: "Morse") else { return }
        sound.volume = Float(appSettings.soundVolume)
        sound.play()
    }
}
