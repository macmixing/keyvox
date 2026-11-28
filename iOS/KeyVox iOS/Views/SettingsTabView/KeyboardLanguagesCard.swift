import SwiftUI

/// The Languages card of the keyboard's Languages settings: the typing language by name when there
/// is one, or how many there are, with a Change button that opens `KeyboardLanguagesScreen`.
struct KeyboardLanguagesCard: View {
    @Environment(\.appHaptics) private var appHaptics
    let selection: KeyboardTypingLanguageSelection
    let onChangeLanguages: () -> Void

    var body: some View {
        AppCard {
            SettingsValueRow(
                icon: "globe",
                title: KeyboardLanguagesSettingsCopy.screenTitle,
                value: value
            ) {
                Button {
                    appHaptics.light()
                    onChangeLanguages()
                } label: {
                    Text(KeyboardLanguagesSettingsCopy.changeLanguagesTitle)
                        .font(.appFont(16))
                        .foregroundStyle(.yellow)
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var value: String {
        if selection.languages.count == 1, let language = selection.languages.first {
            return KeyboardTypingLanguageName.displayName(for: language.identifier)
        }
        return KeyboardLanguagesSettingsCopy.languageCount(selection.languages.count)
    }
}
