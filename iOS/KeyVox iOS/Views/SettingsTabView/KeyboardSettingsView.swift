import SwiftUI

/// The KeyVox keyboard's settings, opened from the Keyboard row in Settings: the typing
/// helps as single-line switches, then the layout options with their descriptions.
struct KeyboardSettingsView: View {
    @EnvironmentObject private var settingsStore: AppSettingsStore

    var body: some View {
        AppScrollScreen(additionalTopContentInset: AppScreenContentInset.tabPageTop) {
            VStack(alignment: .leading, spacing: AppTheme.sectionSpacing) {
                typingSection
                leftHandedLayoutSection
                compactKeysSection
            }
        }
        .navigationTitle(SettingsTabCopy.Keyboard.screenTitle)
        .navigationBarTitleDisplayMode(.inline)
    }

    private var typingSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            AppCard {
                VStack(spacing: 16) {
                    SettingsRow(
                        icon: "iphone.radiowaves.left.and.right",
                        title: SettingsTabCopy.Keyboard.hapticsTitle,
                        isOn: $settingsStore.keyboardHapticsEnabled
                    )
                    divider
                    SettingsRow(
                        icon: "textformat",
                        title: SettingsTabCopy.Keyboard.autoCapitalizationTitle,
                        isOn: $settingsStore.autoCapitalizationEnabled
                    )
                    divider
                    SettingsRow(
                        icon: "text.badge.checkmark",
                        title: SettingsTabCopy.Keyboard.autoCorrectionTitle,
                        isOn: $settingsStore.autoCorrectionEnabled
                    )
                    divider
                    SettingsRow(
                        icon: "capslock",
                        title: SettingsTabCopy.Keyboard.capsLockTitle,
                        isOn: $settingsStore.shiftCapsLockEnabled
                    )
                    divider
                    SettingsRow(
                        icon: "text.word.spacing",
                        title: SettingsTabCopy.Keyboard.predictiveTextTitle,
                        isOn: $settingsStore.predictiveTextEnabled
                    )
                    divider
                    SettingsRow(
                        icon: "space",
                        title: SettingsTabCopy.Keyboard.periodShortcutTitle,
                        isOn: $settingsStore.periodShortcutEnabled
                    )
                }
            }

            Text(SettingsTabCopy.Keyboard.periodShortcutDescription)
                .font(.appFont(15, variant: .light))
                .foregroundStyle(.white.opacity(0.7))
                .padding(.horizontal, AppTheme.cardPadding)
        }
    }

    private var leftHandedLayoutSection: some View {
        AppCard {
            SettingsRow(
                icon: "switch.2",
                title: SettingsTabCopy.Keyboard.leftHandedLayoutTitle,
                description: SettingsTabCopy.Keyboard.leftHandedLayoutDescription,
                isOn: $settingsStore.leftHandedKeyboardLayoutEnabled
            )
        }
    }

    private var compactKeysSection: some View {
        AppCard {
            SettingsRow(
                icon: "keyboard.chevron.compact.down",
                title: SettingsTabCopy.Keyboard.compactKeysTitle,
                description: SettingsTabCopy.Keyboard.compactKeysDescription,
                isOn: $settingsStore.compactKeysEnabled
            )
        }
    }

    private var divider: some View {
        Divider()
            .overlay(.white.opacity(0.22))
    }
}
