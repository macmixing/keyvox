import SwiftUI

extension SettingsView {
    var generalSettings: some View {
        VStack(alignment: .leading, spacing: 10) {
            Spacer().frame(height: 4)
            
            Text("KEYBOARD")
                .font(.custom("Kanit Medium", size: 10))
                .foregroundColor(.secondary.opacity(0.6))
                .padding(.leading, 4)
            
            SettingsCard {
                SettingsRow(
                    icon: "keyboard",
                    title: "Trigger Key",
                    subtitle: "Hold this key to start recording. Release to transcribe."
                ) {
                    Picker("", selection: $appSettings.triggerBinding) {
                        ForEach(KeyboardMonitor.TriggerBinding.allCases) { binding in
                            Text(binding.displayName).tag(binding)
                        }
                    }
                    .pickerStyle(.menu)
                    .frame(width: 160)
                    .labelsHidden()
                }
            }
            
            // Tips as part of General or Info
            tipsSection

            Text("STYLE")
                .font(.custom("Kanit Medium", size: 10))
                .foregroundColor(.secondary.opacity(0.6))
                .padding(.leading, 4)

            SettingsCard {
                VStack(spacing: 12) {
                    SettingsRow(
                        icon: "list.bullet",
                        title: "Lists",
                        subtitle: "Format spoken numbered lists automatically when detected."
                    ) {
                        Toggle("", isOn: $appSettings.listFormattingEnabled)
                            .toggleStyle(.switch)
                            .labelsHidden()
                    }

                    Divider()

                    SettingsRow(
                        icon: "text.alignleft",
                        title: "Paragraphs",
                        subtitle: "Start new paragraphs automatically after brief pauses in multiline fields."
                    ) {
                        Toggle("", isOn: $appSettings.autoParagraphsEnabled)
                            .toggleStyle(.switch)
                            .labelsHidden()
                    }
                }
            }
        }
    }
    
    var tipsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                TipItem(icon: "shift", text: "Shift + Release for Hands-Free")
                TipItem(icon: "escape", text: "Esc to Cancel")
            }
            .frame(maxWidth: .infinity, alignment: .center)
        }
    }
}
