import Foundation
import KeyVoxCore
import SwiftUI

struct OnboardingLanguageScreen: View {
    @Binding var selection: DictationLanguage?
    @State private var searchText = ""

    let onContinue: (DictationLanguage) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            VStack(alignment: .leading, spacing: 7) {
                Text("Choose your language", comment: "Title of the onboarding screen for choosing the dictation language.")
                    .font(.appFont(34))
                    .foregroundStyle(.white)

                Text("We recommend choosing the language you use most for more reliable dictation.", comment: "Subtitle of the onboarding dictation language screen.")
                    .font(.appFont(15, variant: .light))
                    .foregroundStyle(.yellow.opacity(0.78))

                Text("Choose Auto Detect for multilingual conversations. You can change this anytime in Settings.", comment: "Hint on the onboarding dictation language screen. Auto Detect is the name of the automatic language option in the list; translate it the same way as that option. Settings is the KeyVox settings window.")
                    .font(.appFont(13, variant: .light))
                    .foregroundStyle(.white.opacity(0.6))
            }

            HStack(spacing: 10) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.white.opacity(0.5))

                TextField(String(localized: "Search languages", comment: "Placeholder of the search field on the onboarding dictation language screen."), text: $searchText)
                    .textFieldStyle(.plain)
                    .font(.appFont(15, variant: .light))
                    .foregroundStyle(.white)
            }
            .padding(.horizontal, 14)
            .frame(height: 42)
            .background(MacAppTheme.cardFill)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

            ScrollView {
                LazyVStack(spacing: 0) {
                    ForEach(Array(filteredLanguages.enumerated()), id: \.element.id) { index, language in
                        languageButton(language)

                        if index < filteredLanguages.count - 1 || filteredLanguages.count == 1 {
                            Divider()
                                .overlay(.white.opacity(0.14))
                        }
                    }

                    if filteredLanguages.isEmpty {
                        Text("No languages found", comment: "Empty state when a language search on the onboarding screen has no results.")
                            .font(.appFont(14, variant: .light))
                            .foregroundStyle(.white.opacity(0.6))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 18)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 4)
            }
            .background(MacAppTheme.cardFill)
            .overlay {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(MacAppTheme.cardStroke, lineWidth: 1)
            }
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))

            AppActionButton(
                title: String(localized: "Continue", comment: "Button on the onboarding dictation language screen."),
                style: .primary,
                minWidth: 240,
                fontSize: 20,
                isEnabled: selection != nil,
                action: completeSelection
            )
            .frame(maxWidth: .infinity)
        }
        .padding(.horizontal, 30)
        .padding(.top, 28)
        .padding(.bottom, 30)
        .frame(width: OnboardingView.preferredWindowSize.width)
        .frame(height: OnboardingView.preferredWindowSize.height)
        .background(MacAppTheme.screenBackground)
    }

    private var filteredLanguages: [DictationLanguage] {
        guard searchText.isEmpty == false else {
            return whisperLanguages
        }

        return whisperLanguages.filter {
            DictationLanguageDisplayNameFormatter.displayName(for: $0)
                .localizedCaseInsensitiveContains(searchText)
        }
    }

    private var whisperLanguages: [DictationLanguage] {
        let specificLanguages = WhisperBaseLanguageCatalog.supportedLanguages
            .filter { $0.isAutomatic == false }
            .sorted {
                DictationLanguageDisplayNameFormatter.displayName(for: $0)
                    .localizedCaseInsensitiveCompare(
                        DictationLanguageDisplayNameFormatter.displayName(for: $1)
                    ) == .orderedAscending
            }

        return [.automatic] + specificLanguages
    }

    private func languageButton(_ language: DictationLanguage) -> some View {
        Button {
            selection = language
        } label: {
            HStack(spacing: 12) {
                Text(DictationLanguageDisplayNameFormatter.displayName(for: language))
                    .font(.appFont(15))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity, alignment: .leading)

                Image(systemName: selection == language ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 18, weight: .medium))
                    .foregroundStyle(selection == language ? .yellow : .white.opacity(0.3))
            }
            .contentShape(Rectangle())
            .padding(.vertical, 9)
        }
        .buttonStyle(.plain)
    }

    private func completeSelection() {
        guard let selection else { return }
        onContinue(selection)
    }
}
