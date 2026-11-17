import Foundation
import SwiftUI

extension SettingsView {
    var moreSettings: some View {
        VStack(alignment: .leading, spacing: 10) {
            Spacer().frame(height: 4)

            VStack(alignment: .leading, spacing: 10) {
                Text("KEYBOARD", comment: "Section heading on the Settings page, shown in capital letters.")
                    .font(.appFont(10))
                    .foregroundColor(.secondary.opacity(0.6))
                    .padding(.leading, 4)

                VStack(alignment: .leading, spacing: 10) {
                    SettingsCard {
                        SettingsRow(
                            icon: "keyboard",
                            title: String(localized: "Trigger Key", comment: "Title of the Settings row for choosing the dictation trigger key."),
                            subtitle: String(localized: "Hold this key to start recording. Release to transcribe.", comment: "Subtitle of the Trigger Key row in Settings.")
                        ) {
                            Picker("", selection: $appSettings.triggerBinding) {
                                ForEach(KeyboardMonitor.TriggerBinding.allCases) { binding in
                                    Text(binding.displayName).tag(binding)
                                }
                            }
                            .pickerStyle(.menu)
                            .labelsHidden()
                            .menuPickerWidth(fitting: appSettings.triggerBinding.displayName, minimumWidth: 160)
                        }
                    }

                    HStack {
                        Spacer()
                        TipItem(
                            icon: "shift.fill",
                            text: String(localized: "Trigger key + Shift = Hands-free mode", comment: "Tip under the Trigger Key row in Settings. Shift is the keyboard key; use the name macOS uses for it in this language.")
                        )
                        Spacer()
                    }
                }
            }

            VStack(alignment: .leading, spacing: 15) {
                Text("AUDIO", comment: "Section heading on the Settings page, shown in capital letters.")
                    .font(.appFont(10))
                    .foregroundColor(.secondary.opacity(0.6))
                    .padding(.leading, 4)

                microphoneInputCard
                systemSoundsCard
            }

            VStack(alignment: .leading, spacing: 15) {
                Text("SYSTEM", comment: "Section heading on the Settings page, shown in capital letters.")
                    .font(.appFont(10))
                    .foregroundColor(.secondary.opacity(0.6))
                    .padding(.leading, 4)

                launchAtLoginCard
                dictationModelsSection
                SettingsVibesAIInstallCard(
                    triggerKeyInteractionsEnabled: $appSettings.vibesTriggerKeyInteractionsEnabled,
                    installState: localRewriteModelManager.installState,
                    downloadAction: {
                        localRewriteModelManager.downloadModel()
                    },
                    repairAction: {
                        localRewriteModelManager.downloadModel()
                    },
                    deleteAction: {
                        isVibesAIDeleteConfirmationPresented = true
                    }
                )
            }
            
            // More from Developer Section
            VStack(alignment: .leading, spacing: 15) {
                Text("MORE", comment: "Section heading on the Settings page, shown in capital letters.")
                    .font(.appFont(10))
                    .foregroundColor(.secondary.opacity(0.6))
                    .padding(.leading, 4)

                DeveloperLinkCard(
                    icon: .assetTemplate("github"),
                    title: String(localized: "Sponsor on GitHub", comment: "Title of the sponsor card in Settings. GitHub is a brand name and stays in English."),
                    subtitle: String(localized: "Support open source development of KeyVox via GitHub Sponsors.", comment: "Subtitle of the sponsor card in Settings. KeyVox and GitHub Sponsors are brand names and stay in English."),
                    buttonTitle: String(localized: "Sponsor", comment: "Button on the sponsor card in Settings that opens the GitHub Sponsors page."),
                    buttonStyle: .primary
                ) {
                    openDeveloperURL("https://github.com/sponsors/macmixing")
                }

                DeveloperLinkCard(
                    icon: .systemImage("questionmark.circle.fill"),
                    title: String(localized: "Need Help?", comment: "Title of the help card in Settings."),
                    subtitle: String(localized: "Get help with KeyVox, download the iPhone app, read the FAQ, find more information, or contact us.", comment: "Subtitle of the help card in Settings. KeyVox is a brand name and stays in English. iPhone is an Apple product name; use Apple's official name in this language."),
                    buttonTitle: String(localized: "Open", comment: "Button on the help card in Settings that opens the KeyVox help website."),
                    buttonStyle: .primary
                ) {
                    openDeveloperURL("https://keyvox.app/?utm_source=keyvox_mac&utm_medium=settings&utm_campaign=help_card#faq-mac")
                }
            }
            
            HStack {
                Button(action: { showLegal = true }) {
                    HStack(alignment: .firstTextBaseline, spacing: 6) {
                        Image(systemName: "doc.text.fill")
                            .font(.system(size: 12))
                        Text("Legal & Licenses", comment: "Button at the bottom of the Settings page that opens the Legal & Licenses window.")
                    }
                    .font(.appFont(13))
                    .foregroundColor(MacAppTheme.accent)
                }
                .buttonStyle(DepressedButtonStyle())
                .padding(.leading, 8)

                Spacer()

                Text("Version \(appVersion)", comment: "App version shown at the bottom of the Settings page. %@ is the app version.")
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

    private var launchAtLoginCard: some View {
        SettingsCard {
            VStack(alignment: .leading, spacing: 10) {
                SettingsRow(
                    icon: "person.crop.circle.badge.checkmark",
                    title: String(localized: "Launch at Login", comment: "Title of the Settings row for starting KeyVox when the user logs in."),
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
                    Button(String(localized: "Open Login Items Settings", comment: "Button in Settings that opens the Login Items page of System Settings. Use the names macOS uses for Login Items and System Settings in this language.")) {
                        loginItemController.openLoginItemsSettings()
                    }
                    .font(.appFont(12))
                    .foregroundColor(MacAppTheme.accent)
                    .buttonStyle(DepressedButtonStyle())
                }

                if shouldShowHideDockIconSetting {
                    Divider()
                        .background(Color.white.opacity(0.22))

                    SettingsRow(
                        icon: "dock.rectangle",
                        title: String(localized: "Hide Dock Icon", comment: "Title of the Settings row and VoiceOver label of its toggle for hiding the KeyVox icon in the Dock. Use the name macOS uses for the Dock in this language."),
                        subtitle: String(localized: "Hide dock icon when all windows are closed.", comment: "Subtitle of the Hide Dock Icon row in Settings. Use the name macOS uses for the Dock in this language.")
                    ) {
                        Toggle("", isOn: $appSettings.hideDockIconWhenAllWindowsClosed)
                            .toggleStyle(.switch)
                            .labelsHidden()
                            .accessibilityLabel(String(localized: "Hide Dock Icon", comment: "Title of the Settings row and VoiceOver label of its toggle for hiding the KeyVox icon in the Dock. Use the name macOS uses for the Dock in this language."))
                    }
                }
            }
        }
    }

    private var shouldShowHideDockIconSetting: Bool {
        !KeyVoxApp.shouldUseAccessoryActivationPolicy()
    }

    private func isRecommendedMicrophone(_ microphone: MicrophoneOption) -> Bool {
        microphone.kind == .builtIn
    }

    private var microphoneInputCard: some View {
        SettingsCard {
            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .audioHeaderCenter, spacing: 16) {
                    ZStack {
                        Circle()
                            .fill(MacAppTheme.iconFill)
                            .frame(width: 44, height: 44)
                        Image(systemName: "mic.fill")
                            .font(.appFont(20))
                            .foregroundColor(.yellow)
                    }
                    .alignmentGuide(.audioHeaderCenter) { dimensions in
                        dimensions[VerticalAlignment.center]
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        Text("Mic Input", comment: "Title of the microphone card in Settings.")
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
                    Circle()
                        .fill(MacAppTheme.iconFill)
                        .frame(width: 44, height: 44)
                    Image(systemName: "speaker.wave.2.fill")
                        .font(.appFont(20))
                        .foregroundColor(.yellow)
                }
                .alignmentGuide(.audioHeaderCenter) { dimensions in
                    dimensions[VerticalAlignment.center]
                }

                VStack(alignment: .leading, spacing: 12) {
                    HStack(alignment: .top, spacing: 16) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("System Sounds", comment: "Title of the sound feedback card in Settings and VoiceOver label of its toggle.")
                                .font(.appFont(17))

                            Text("Play audio feedback when recording starts and ends.", comment: "Subtitle of the System Sounds card in Settings.")
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
                            .accessibilityLabel(String(localized: "System Sounds", comment: "Title of the sound feedback card in Settings and VoiceOver label of its toggle."))
                    }

                    VStack(alignment: .leading, spacing: 6) {
                        Text("Adjust volume", comment: "Label above the sound volume slider in Settings.")
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

                            Text(appSettings.soundVolume.formatted(.percent.precision(.fractionLength(0)).rounded(rule: .toNearestOrAwayFromZero)))
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
                return String(localized: "Selected mic is unavailable. Built-in Microphone will be used until it reconnects.", comment: "Subtitle of the Mic Input card in Settings. Shown when the chosen microphone is disconnected. Built-in Microphone is the macOS name for the Mac's own microphone; use the name macOS uses in this language.")
            }
            return String(localized: "Built-in Microphone is recommended for the fastest and most reliable dictation.", comment: "Subtitle of the Mic Input card in Settings. Shown when no microphone is chosen. Built-in Microphone is the macOS name for the Mac's own microphone; use the name macOS uses in this language.")
        }

        switch selected.kind {
        case .builtIn:
            if isRecommendedMicrophone(selected) {
                return String(localized: "\(selected.name) selected. Recommended for fastest startup and best reliability.", comment: "Subtitle of the Mic Input card in Settings. Shown when the Mac's own microphone is chosen. %@ is the selected microphone's name.")
            }
            return String(localized: "\(selected.name) selected.", comment: "Subtitle of the Mic Input card in Settings. %@ is the selected microphone's name.")
        case .airPods:
            return String(localized: "\(selected.name) selected. This microphone may start slower and reduce dictation accuracy.", comment: "Subtitle of the Mic Input card in Settings. Shown when AirPods are chosen. %@ is the selected microphone's name.")
        case .bluetooth:
            return String(localized: "\(selected.name) selected. Bluetooth devices may start slower and reduce dictation accuracy.", comment: "Subtitle of the Mic Input card in Settings. Shown when a Bluetooth microphone is chosen. Bluetooth is a brand name and stays in English. %@ is the selected microphone's name.")
        case .wiredOrOther:
            return String(localized: "\(selected.name) selected. Built-in Microphone is still recommended for best speed.", comment: "Subtitle of the Mic Input card in Settings. Shown when a wired or other microphone is chosen. Built-in Microphone is the macOS name for the Mac's own microphone; use the name macOS uses in this language. %@ is the selected microphone's name.")
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
            return String(localized: "Previously Selected Microphone (Unavailable)", comment: "Microphone picker entry for a microphone that was chosen before but is no longer connected.")
        }

        if isRecommendedMicrophone(microphone) {
            return String(localized: "\(microphone.name) (Recommended)", comment: "Microphone picker entry for the recommended microphone in Settings. %@ is the microphone's name.")
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
