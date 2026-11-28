import KeyVoxTypingLanguageCatalog
import SwiftUI

/// The keyboard's typing languages, opened full screen from the Languages card of the keyboard's
/// Languages settings: the shared language list with any number of languages checked, the checked ones in
/// the order the space bar switches through them. Done saves the choice.
struct KeyboardLanguagesScreen: View {
    @EnvironmentObject private var settingsStore: AppSettingsStore
    @FocusState private var isSearchFocused: Bool
    @State private var selected: [String] = []
    let selection: KeyboardTypingLanguageSelection
    let onDone: () -> Void

    var body: some View {
        LanguageListScreen(
            options: options,
            selection: .multiple($selected),
            actionTitle: KeyboardSettingsCopy.languagesDoneTitle,
            isSearchFocused: $isSearchFocused,
            onAction: save
        ) {
            VStack(alignment: .leading, spacing: 8) {
                Text(KeyboardSettingsCopy.languagesScreenTitle)
                    .font(.appFont(30))
                    .foregroundStyle(.white)

                Text(KeyboardSettingsCopy.languagesScreenAdvice)
                    .font(.appFont(17, variant: .light))
                    .foregroundStyle(.yellow.opacity(0.78))
            }
        }
        .onAppear {
            selected = selection.identifiers
        }
    }

    /// Every language the keyboard bundles, alphabetical by the name shown.
    private var options: [LanguageListOption] {
        KeyboardBundledTypingLanguages.catalog.languages
            .map { LanguageListOption(id: $0.identifier, name: KeyboardTypingLanguageName.displayName(for: $0.identifier)) }
            .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    private func save() {
        guard selected.isEmpty == false else { return }
        isSearchFocused = false
        settingsStore.keyboardTypingLanguages = selected
        onDone()
    }
}
