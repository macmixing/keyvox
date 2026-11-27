import KeyVoxKeyboardThemes
import SwiftUI

/// The KeyVox keyboard's settings, opened from the Keyboard row in Settings: the typing
/// toggles as single-line rows, then the typing languages and their letter layouts, then the layout
/// options with their descriptions, then resetting what the keyboard learned from the user's typing.
struct KeyboardSettingsView: View {
    @EnvironmentObject private var settingsStore: AppSettingsStore
    @Binding var pendingDeletionConfirmation: SettingsPendingDeletionConfirmation?
    @State private var isLanguageListPresented = false

    var body: some View {
        AppScrollScreen(additionalTopContentInset: AppScreenContentInset.tabPageTop) {
            VStack(alignment: .leading, spacing: AppTheme.sectionSpacing) {
                typingSection
                languagesSection
                classicThemeSection
                compactKeysSection
                openOnNumberPageSection
                leftHandedLayoutSection
                resetLearnedWordsSection
                englishOnlyNote
            }
        }
        .navigationTitle(KeyboardSettingsCopy.screenTitle)
        .navigationBarTitleDisplayMode(.inline)
        .fullScreenCover(isPresented: $isLanguageListPresented) {
            KeyboardLanguagesScreen(selection: typingLanguageSelection) {
                isLanguageListPresented = false
            }
        }
    }

    private var typingLanguageSelection: KeyboardTypingLanguageSelection {
        KeyboardTypingLanguageSelection(
            savedLanguages: settingsStore.keyboardTypingLanguages,
            savedLetterLayouts: settingsStore.keyboardLetterLayouts,
            catalog: KeyboardBundledTypingLanguages.catalog,
            fallbackLanguage: Bundle.main.developmentLocalization
        )
    }

    private var languagesSection: some View {
        KeyboardLanguagesCard(selection: typingLanguageSelection) {
            isLanguageListPresented = true
        }
    }

    private var typingSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            AppCard {
                VStack(spacing: 16) {
                    if AppDevice.isPad == false {
                        SettingsRow(
                            icon: "iphone.radiowaves.left.and.right",
                            title: KeyboardSettingsCopy.hapticsTitle,
                            isOn: $settingsStore.keyboardHapticsEnabled
                        )
                        divider
                    }
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
                        icon: "hand.draw",
                        title: KeyboardSettingsCopy.swipeTypingTitle,
                        isOn: $settingsStore.swipeTypingEnabled
                    )
                    divider
                    SettingsRow(
                        // Drawn as an outline on this always-dark screen.
                        icon: "face.smiling.inverse",
                        title: KeyboardSettingsCopy.emojiKeyboardTitle,
                        isOn: $settingsStore.emojiKeyboardEnabled
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

    private var classicThemeSection: some View {
        AppCard {
            SettingsRow(
                icon: "paintpalette",
                title: KeyboardSettingsCopy.classicThemeTitle,
                description: KeyboardSettingsCopy.classicThemeDescription,
                isOn: Binding(
                    get: { settingsStore.keyboardTheme == .classic },
                    set: { settingsStore.keyboardTheme = $0 ? .classic : .keyVox }
                )
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

    private var resetLearnedWordsSection: some View {
        VStack(spacing: 8) {
            AppActionButton(
                title: KeyboardSettingsCopy.resetLearnedWordsTitle,
                style: .secondary,
                fillsWidth: true,
                size: .regular,
                fontSize: 16,
                action: { pendingDeletionConfirmation = .learnedWords }
            )

            Text(KeyboardSettingsCopy.resetLearnedWordsHint)
                .font(.appFont(15, variant: .light))
                .foregroundStyle(.white.opacity(0.7))
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity, alignment: .center)
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
