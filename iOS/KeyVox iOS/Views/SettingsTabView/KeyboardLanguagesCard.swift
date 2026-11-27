import SwiftUI

/// The Languages card of Keyboard settings: the typing languages, with a Change button that opens
/// `KeyboardLanguagesScreen`, then the letter layout of each, picked from the layouts the language
/// offers in Apple's order. A language with one layout shows it without a Change menu.
struct KeyboardLanguagesCard: View {
    @Environment(\.appHaptics) private var appHaptics
    @EnvironmentObject private var settingsStore: AppSettingsStore
    let selection: KeyboardTypingLanguageSelection
    let onChangeLanguages: () -> Void

    var body: some View {
        AppCard {
            VStack(alignment: .leading, spacing: 16) {
                valueRow(
                    icon: "globe",
                    title: KeyboardSettingsCopy.languagesTitle,
                    value: languageNames
                ) {
                    Button {
                        appHaptics.light()
                        onChangeLanguages()
                    } label: {
                        Text(KeyboardSettingsCopy.changeLanguagesTitle)
                            .font(.appFont(16))
                            .foregroundStyle(.yellow)
                    }
                    .buttonStyle(.plain)
                }

                ForEach(selection.languages, id: \.identifier) { language in
                    Divider()
                        .overlay(.white.opacity(0.22))

                    layoutRow(language)
                }
            }
        }
    }

    private var languageNames: String {
        selection.languages
            .map { KeyboardTypingLanguageName.displayName(for: $0.identifier) }
            .formatted(.list(type: .and, width: .narrow).locale(KeyboardTypingLanguageName.shownLocale))
    }

    @ViewBuilder
    private func layoutRow(_ language: KeyboardTypingLanguageSelection.Language) -> some View {
        let title = selection.languages.count > 1
            ? KeyboardSettingsCopy.layoutTitle(languageName: KeyboardTypingLanguageName.displayName(for: language.identifier))
            : KeyboardSettingsCopy.layoutTitle
        valueRow(icon: "keyboard", title: title, value: language.letterLayout) {
            if language.letterLayouts.count > 1 {
                Menu {
                    Picker("", selection: layoutBinding(for: language)) {
                        ForEach(language.letterLayouts, id: \.self) { layout in
                            Text(verbatim: layout).tag(layout)
                        }
                    }
                    .pickerStyle(.inline)
                } label: {
                    Text(KeyboardSettingsCopy.changeLayoutTitle)
                        .font(.appFont(16))
                        .foregroundColor(.yellow)
                }
            }
        }
    }

    private func layoutBinding(for language: KeyboardTypingLanguageSelection.Language) -> Binding<String> {
        Binding(
            get: { language.letterLayout },
            set: { settingsStore.keyboardLetterLayouts[language.identifier] = $0 }
        )
    }

    private func valueRow<Trailing: View>(
        icon: String,
        title: String,
        value: String,
        @ViewBuilder trailing: () -> Trailing
    ) -> some View {
        HStack(alignment: .top, spacing: 12) {
            ZStack {
                Circle()
                    .fill(AppTheme.accent.opacity(0.4))
                    .frame(width: 32, height: 32)

                Image(systemName: icon)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.yellow)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.appFont(18))
                    .foregroundStyle(.white)

                Text(verbatim: value)
                    .font(.appFont(17))
                    .foregroundStyle(.yellow)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            trailing()
                .padding(.top, 2)
        }
    }
}
