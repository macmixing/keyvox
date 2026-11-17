import Foundation
import KeyVoxCore
import SwiftUI

struct DictationLanguageSection: View {
    let activeProvider: AppSettingsStore.ActiveDictationProvider
    @Binding var selectedWhisperLanguage: DictationLanguage

    var body: some View {
        SettingsRow(
            icon: "textformat.characters.dottedunderline",
            title: DictationLanguageSectionCopy.title,
            subtitle: descriptionText
        ) {
            if activeProvider == .whisper {
                Picker("", selection: whisperLanguageSelection) {
                    ForEach(whisperLanguageOptions) { language in
                        Text(DictationLanguageDisplayNameFormatter.displayName(for: language))
                            .tag(language)
                    }
                }
                .pickerStyle(.menu)
                .labelsHidden()
                .accessibilityLabel(DictationLanguageSectionCopy.pickerAccessibilityLabel)
                .menuPickerWidth(
                    fitting: DictationLanguageDisplayNameFormatter.displayName(for: whisperLanguageSelection.wrappedValue),
                    minimumWidth: 160
                )
            } else {
                Picker("", selection: automaticLanguageSelection) {
                    Text(DictationLanguageDisplayNameFormatter.displayName(for: .automatic))
                        .tag(DictationLanguage.automatic)
                }
                .pickerStyle(.menu)
                .labelsHidden()
                .disabled(true)
                .accessibilityLabel(DictationLanguageSectionCopy.pickerAccessibilityLabel)
                .menuPickerWidth(
                    fitting: DictationLanguageDisplayNameFormatter.displayName(for: .automatic),
                    minimumWidth: 160
                )
            }
        }
    }

    private var whisperLanguageSelection: Binding<DictationLanguage> {
        Binding(
            get: { selectedWhisperLanguage },
            set: { newValue in
                guard WhisperBaseLanguageCatalog.supports(newValue) else { return }
                selectedWhisperLanguage = newValue
            }
        )
    }

    private var automaticLanguageSelection: Binding<DictationLanguage> {
        Binding(
            get: { .automatic },
            set: { _ in }
        )
    }

    private var whisperLanguageOptions: [DictationLanguage] {
        let languageOptions = WhisperBaseLanguageCatalog.supportedLanguages
            .filter { !$0.isAutomatic }
            .sorted {
                DictationLanguageDisplayNameFormatter.displayName(for: $0)
                    .localizedCaseInsensitiveCompare(
                        DictationLanguageDisplayNameFormatter.displayName(for: $1)
                    ) == .orderedAscending
            }

        return [.automatic] + languageOptions
    }

    private var descriptionText: String {
        switch activeProvider {
        case .whisper:
            return DictationLanguageSectionCopy.whisperDescription
        case .parakeet:
            return DictationLanguageSectionCopy.parakeetDescription
        }
    }
}

private enum DictationLanguageSectionCopy {
    static let title = String(localized: "Language", comment: "Title of the dictation language row in Settings.")
    static let pickerAccessibilityLabel = String(localized: "Dictation Language", comment: "VoiceOver label for the dictation language picker in Settings.")
    static let whisperDescription = String(localized: "Choose the language KeyVox uses for dictation.", comment: "Description of the dictation language row in Settings when Whisper is the dictation model. KeyVox is a brand name and stays in English.")
    static let parakeetDescription = String(localized: "Parakeet automatically detects the language used for dictation. Visit the FAQ in the Need Help? card to see its supported languages.", comment: "Description of the dictation language row in Settings when Parakeet is the dictation model. Parakeet is a brand name and stays in English. Need Help? is the title of a card in Settings; translate it the same way as that card's title.")
}
