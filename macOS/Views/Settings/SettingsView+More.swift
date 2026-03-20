import SwiftUI

extension SettingsView {
    var moreSettings: some View {
        VStack(alignment: .leading, spacing: 10) {
            Spacer().frame(height: 4)

            VStack(alignment: .leading, spacing: 10) {
                Text("KEYBOARD")
                    .font(.appFont(10))
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
            }

            VStack(alignment: .leading, spacing: 15) {
                Text("AUDIO")
                    .font(.appFont(10))
                    .foregroundColor(.secondary.opacity(0.6))
                    .padding(.leading, 4)

                microphoneInputCard
                systemSoundsCard
            }

            VStack(alignment: .leading, spacing: 10) {
                Text("SYSTEM")
                    .font(.appFont(10))
                    .foregroundColor(.secondary.opacity(0.6))
                    .padding(.leading, 4)

                SettingsCard {
                    VStack(alignment: .leading, spacing: 10) {
                        SettingsRow(
                            icon: "person.crop.circle.badge.checkmark",
                            title: "Launch at Login",
                            subtitle: loginItemController.subtitle
                        ) {
                            Toggle(
                                "",
                                isOn: Binding(
                                    get: { loginItemController.isEnabled },
                                    set: { loginItemController.setEnabled($0) }
                                )
                            )
                            .toggleStyle(.switch)
                            .labelsHidden()
                            .disabled(loginItemController.isUpdating)
                        }

                        if let errorMessage = loginItemController.errorMessage {
                            Text(errorMessage)
                                .font(.appFont(11))
                                .foregroundColor(.orange)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }

                        if loginItemController.shouldShowOpenSystemSettingsAction {
                            Button("Open Login Items Settings") {
                                loginItemController.openLoginItemsSettings()
                            }
                            .font(.appFont(12))
                            .foregroundColor(MacAppTheme.accent)
                            .buttonStyle(DepressedButtonStyle())
                        }

                        Divider()
                            .overlay(Color.white.opacity(0.14))
                            .padding(.vertical, 2)

                        ModelSettingsRow(downloader: downloader)
                    }
                }
            }
            
            // More from Developer Section
            VStack(alignment: .leading, spacing: 15) {
                Text("MORE FROM DEVELOPER")
                    .font(.appFont(10))
                    .foregroundColor(.secondary.opacity(0.6))
                    .padding(.leading, 4)

                DeveloperLinkCard(
                    icon: .asset("cueboard-logo"),
                    title: "Cueboard",
                    subtitle: "Cueboard is a shot list planning tool for creators who think visually. Compatible with iPhone, iPad, and Apple Silicon Mac.",
                    buttonTitle: "View"
                ) {
                    openDeveloperURL("https://cueboard.app?utm_source=keyvox-app-settings")
                }

                DeveloperLinkCard(
                    icon: .assetTemplate("github"),
                    title: "Sponsor on GitHub",
                    subtitle: "Support open source development of KeyVox via GitHub Sponsors.",
                    buttonTitle: "Sponsor"
                ) {
                    openDeveloperURL("https://github.com/sponsors/macmixing")
                }
            }
            
            HStack {
                Button(action: { showLegal = true }) {
                    HStack(alignment: .firstTextBaseline, spacing: 6) {
                        Image(systemName: "doc.text.fill")
                            .font(.system(size: 12))
                        Text("Legal & Licenses")
                    }
                    .font(.appFont(13))
                    .foregroundColor(MacAppTheme.accent)
                }
                .buttonStyle(DepressedButtonStyle())
                .padding(.leading, 8)

                Spacer()

                Text("Version \(appVersion)")
                    .font(.appFont(10))
                    .foregroundColor(.secondary.opacity(0.5))
                    .padding(.trailing, 8)
            }
            .padding(.top, 8)
        }
        .onAppear {
            loginItemController.refreshStatus()
        }
    }

    private func isRecommendedMicrophone(_ microphone: MicrophoneOption) -> Bool {
        microphone.kind == .builtIn
    }

    private var microphoneInputCard: some View {
        SettingsCard {
            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .audioHeaderCenter, spacing: 16) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 12)
                            .fill(MacAppTheme.iconFill)
                            .frame(width: 44, height: 44)
                        Image(systemName: "mic.fill")
                            .font(.appFont(20))
                            .foregroundColor(MacAppTheme.accent)
                    }
                    .alignmentGuide(.audioHeaderCenter) { dimensions in
                        dimensions[VerticalAlignment.center]
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        Text("Mic Input")
                            .font(.appFont(17))

                        Text(microphoneSubtitle)
                            .font(.appFont(12, variant: .light))
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
    }

    private var systemSoundsCard: some View {
        SettingsCard {
            HStack(alignment: .audioHeaderCenter, spacing: 16) {
                ZStack {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(MacAppTheme.iconFill)
                        .frame(width: 44, height: 44)
                    Image(systemName: "speaker.wave.2.fill")
                        .font(.appFont(20))
                        .foregroundColor(MacAppTheme.accent)
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
                                .font(.appFont(12, variant: .light))
                                .foregroundColor(.secondary)
                                .lineSpacing(2)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        .alignmentGuide(.audioHeaderCenter) { dimensions in
                            dimensions[VerticalAlignment.center]
                        }

                        Spacer(minLength: 16)

                        Toggle("", isOn: $appSettings.isSoundEnabled)
                            .toggleStyle(SwitchToggleStyle(tint: MacAppTheme.accent))
                            .labelsHidden()
                            .accessibilityLabel("System Sounds")
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
                            .tint(MacAppTheme.accent)
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

    private var microphoneSubtitle: String {
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

    private var microphoneSubtitleColor: Color {
        guard let selected = audioDeviceManager.selectedMicrophone else {
            return .yellow
        }

        switch selected.kind {
        case .airPods, .bluetooth:
            return .yellow
        case .builtIn, .wiredOrOther:
            return .secondary
        }
    }

    private func microphonePickerLabel(for microphone: MicrophoneOption) -> String {
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

    private func openDeveloperURL(_ urlString: String) {
        guard let url = URL(string: urlString) else { return }
        NSWorkspace.shared.open(url)
        dismiss()
    }
}

private extension VerticalAlignment {
    private struct AudioHeaderCenterAlignment: AlignmentID {
        static func defaultValue(in dimensions: ViewDimensions) -> CGFloat {
            dimensions[VerticalAlignment.center]
        }
    }

    static let audioHeaderCenter = VerticalAlignment(AudioHeaderCenterAlignment.self)
}

private struct DeveloperLinkCard: View {
    enum Icon {
        case asset(String)
        case assetTemplate(String)
        case systemImage(String)
    }

    let icon: Icon
    let title: String
    let subtitle: String
    let buttonTitle: String
    let action: () -> Void

    var body: some View {
        SettingsCard {
            HStack(spacing: 16) {
                iconView

                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.appFont(16))
                    Text(subtitle)
                        .font(.appFont(11))
                        .foregroundColor(.secondary)
                        .lineSpacing(2)
                }

                Spacer()

                Button(action: action) {
                    Text(buttonTitle)
                        .font(.appFont(12))
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(MacAppTheme.accent.opacity(0.2))
                        .foregroundColor(MacAppTheme.accent)
                        .cornerRadius(8)
                }
                .buttonStyle(DepressedButtonStyle())
            }
        }
    }

    @ViewBuilder
    private var iconView: some View {
        switch icon {
        case .asset(let name):
            Image(name)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 44, height: 44)
                .cornerRadius(12)
        case .assetTemplate(let name):
            ZStack {
                RoundedRectangle(cornerRadius: 12)
                    .fill(MacAppTheme.iconFill)
                    .frame(width: 44, height: 44)
                Image(name)
                    .resizable()
                    .renderingMode(.template)
                    .foregroundColor(.yellow.opacity(0.85))
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 26, height: 26)
            }
        case .systemImage(let name):
            ZStack {
                RoundedRectangle(cornerRadius: 12)
                    .fill(MacAppTheme.iconFill)
                    .frame(width: 44, height: 44)
                Image(systemName: name)
                    .font(.appFont(20))
                    .foregroundColor(.yellow)
            }
        }
    }
}
