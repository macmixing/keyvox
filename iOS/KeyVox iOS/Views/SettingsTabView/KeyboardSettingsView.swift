import SwiftUI

/// The KeyVox keyboard's settings, opened from the Keyboard row in Settings: the typing
/// helps as single-line switches, then the layout options with their descriptions.
struct KeyboardSettingsView: View {
    @EnvironmentObject private var settingsStore: AppSettingsStore

    var body: some View {
        AppScrollScreen(additionalTopContentInset: AppScreenContentInset.tabPageTop) {
            VStack(alignment: .leading, spacing: AppTheme.sectionSpacing) {
                typingSection
                compactKeysSection
                openOnNumberPageSection
                leftHandedLayoutSection
                englishOnlyNote
            }
        }
        .navigationTitle(KeyboardSettingsCopy.screenTitle)
        .navigationBarTitleDisplayMode(.inline)
    }

    private var typingSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            AppCard {
                VStack(spacing: 16) {
                    SettingsRow(
                        icon: "iphone.radiowaves.left.and.right",
                        title: KeyboardSettingsCopy.hapticsTitle,
                        isOn: $settingsStore.keyboardHapticsEnabled
                    )
                    divider
                    SettingsRow(
                        icon: "textformat",
                        title: KeyboardSettingsCopy.autoCapitalizationTitle,
                        isOn: $settingsStore.autoCapitalizationEnabled
                    )
                    divider
                    SettingsRow(
                        icon: "text.badge.checkmark",
                        title: KeyboardSettingsCopy.autoCorrectionTitle,
                        isOn: $settingsStore.autoCorrectionEnabled
                    )
                    divider
                    SettingsRow(
                        icon: "capslock",
                        title: KeyboardSettingsCopy.capsLockTitle,
                        isOn: $settingsStore.shiftCapsLockEnabled
                    )
                    divider
                    SettingsRow(
                        icon: "text.word.spacing",
                        title: KeyboardSettingsCopy.predictiveTextTitle,
                        isOn: $settingsStore.predictiveTextEnabled
                    )
                    divider
                    SettingsRow(
                        icon: "space",
                        title: KeyboardSettingsCopy.periodShortcutTitle,
                        isOn: $settingsStore.periodShortcutEnabled
                    )
                }
            }

            Text(KeyboardSettingsCopy.periodShortcutDescription)
                .font(.appFont(15, variant: .light))
                .foregroundStyle(.white.opacity(0.7))
                .padding(.horizontal, AppTheme.cardPadding)
        }
    }

    private var leftHandedLayoutSection: some View {
        AppCard {
            SettingsRow(
                icon: "switch.2",
                title: KeyboardSettingsCopy.leftHandedLayoutTitle,
                description: KeyboardSettingsCopy.leftHandedLayoutDescription,
                isOn: $settingsStore.leftHandedKeyboardLayoutEnabled
            )
        }
    }

    private var compactKeysSection: some View {
        AppCard {
            SettingsRow(
                icon: "keyboard.chevron.compact.down",
                title: KeyboardSettingsCopy.compactKeysTitle,
                description: KeyboardSettingsCopy.compactKeysDescription,
                isOn: $settingsStore.compactKeysEnabled
            )
        }
    }

    private var openOnNumberPageSection: some View {
        AppCard {
            SettingsRow(
                icon: "textformat.123",
                title: KeyboardSettingsCopy.openOnNumberPageTitle,
                description: KeyboardSettingsCopy.openOnNumberPageDescription,
                isOn: $settingsStore.opensOnNumberPage
            )
        }
    }

    private var englishOnlyNote: some View {
        Text(KeyboardSettingsCopy.englishOnlyNote)
            .font(.appFont(15, variant: .light))
            .foregroundStyle(.yellow.opacity(0.7))
            .multilineTextAlignment(.center)
            .frame(maxWidth: .infinity, alignment: .center)
    }

    private var divider: some View {
        Divider()
            .overlay(.white.opacity(0.22))
    }
}
