import SwiftUI

/// The Layout card of the keyboard's Languages settings, with one Change menu however many typing
/// languages there are. With one language it shows that language's layout, and the menu lists its
/// layouts in Apple's order; a language with one layout has no menu. With several it shows a
/// description in place of the layouts, and the menu lists every language in space-bar order with
/// its layout under its name: a language that offers more than one layout opens them, and a
/// language with one layout cannot be opened. Layouts show by the name Apple's settings show for
/// them (`KeyboardLetterLayoutName`).
struct KeyboardLayoutsCard: View {
    @EnvironmentObject private var settingsStore: AppSettingsStore
    let selection: KeyboardTypingLanguageSelection

    var body: some View {
        AppCard {
            if selection.languages.count > 1 {
                SettingsRow(
                    icon: "keyboard",
                    title: KeyboardLanguagesSettingsCopy.layoutsTitle,
                    description: KeyboardLanguagesSettingsCopy.layoutsDescription
                ) {
                    changeMenu {
                        ForEach(selection.languages, id: \.identifier) { language in
                            languageMenuItem(language)
                        }
                    }
                }
            } else if let language = selection.languages.first {
                SettingsValueRow(
                    icon: "keyboard",
                    title: KeyboardLanguagesSettingsCopy.layoutTitle,
                    value: KeyboardLetterLayoutName.displayName(for: language.letterLayout)
                ) {
                    if language.letterLayouts.count > 1 {
                        changeMenu {
                            layoutPicker(for: language)
                        }
                    }
                }
            }
        }
    }

    private func changeMenu<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        Menu(content: content) {
            Text(KeyboardLanguagesSettingsCopy.changeLayoutTitle)
                .font(.appFont(16))
                .foregroundColor(.yellow)
        }
    }

    @ViewBuilder
    private func languageMenuItem(_ language: KeyboardTypingLanguageSelection.Language) -> some View {
        if language.letterLayouts.count > 1 {
            Menu {
                layoutPicker(for: language)
            } label: {
                languageMenuLabel(language)
            }
        } else {
            Button {} label: {
                languageMenuLabel(language)
            }
            .disabled(true)
        }
    }

    /// The language's name with its layout as the menu item's second line.
    @ViewBuilder
    private func languageMenuLabel(_ language: KeyboardTypingLanguageSelection.Language) -> some View {
        Text(verbatim: KeyboardTypingLanguageName.displayName(for: language.identifier))
        Text(verbatim: KeyboardLetterLayoutName.displayName(for: language.letterLayout))
    }

    private func layoutPicker(for language: KeyboardTypingLanguageSelection.Language) -> some View {
        Picker("", selection: layoutBinding(for: language)) {
            ForEach(language.letterLayouts, id: \.self) { layout in
                Text(verbatim: KeyboardLetterLayoutName.displayName(for: layout)).tag(layout)
            }
        }
        .pickerStyle(.inline)
    }

    private func layoutBinding(for language: KeyboardTypingLanguageSelection.Language) -> Binding<String> {
        Binding(
            get: { language.letterLayout },
            set: { settingsStore.keyboardLetterLayouts[language.identifier] = $0 }
        )
    }
}
