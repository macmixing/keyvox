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
                .frame(width: 160)
                .labelsHidden()
                .accessibilityLabel(DictationLanguageSectionCopy.pickerAccessibilityLabel)
            } else {
                Picker("", selection: automaticLanguageSelection) {
                    Text(DictationLanguageDisplayNameFormatter.displayName(for: .automatic))
                        .tag(DictationLanguage.automatic)
                }
                .pickerStyle(.menu)
                .frame(width: 160)
                .labelsHidden()
                .disabled(true)
                .accessibilityLabel(DictationLanguageSectionCopy.pickerAccessibilityLabel)
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
    static let title = "Language"
    static let pickerAccessibilityLabel = "Dictation Language"
    static let whisperDescription = "Choose the language KeyVox uses for dictation."
    static let parakeetDescription = "Parakeet automatically detects the language used for dictation. Visit the FAQ in the Need Help? card to see its supported languages."
}
