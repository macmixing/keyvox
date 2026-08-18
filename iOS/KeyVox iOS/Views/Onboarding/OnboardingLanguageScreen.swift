import KeyVoxCore
import SwiftUI

struct OnboardingLanguageScreen: View {
    @Environment(\.appHaptics) private var appHaptics
    @EnvironmentObject private var onboardingStore: OnboardingStore
    @EnvironmentObject private var settingsStore: AppSettingsStore
    @FocusState private var isSearchFocused: Bool
    @State private var selection: DictationLanguage?
    @State private var searchText = ""
    @State private var isAdvancing = false
    @State private var advanceTask: Task<Void, Never>?

    var body: some View {
        AppScrollScreen {
            VStack(alignment: .leading, spacing: 20) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Choose your language")
                        .font(.appFont(34))
                        .foregroundStyle(.white)

                    Text("We recommend choosing the language you use most for more reliable dictation.")
                        .font(.appFont(17, variant: .light))
                        .foregroundStyle(.yellow.opacity(0.78))

                    Text("Choose Auto Detect for multilingual conversations. You can change this anytime in Settings.")
                        .font(.appFont(15, variant: .light))
                        .foregroundStyle(.white.opacity(0.6))
                }

                HStack(spacing: 10) {
                    Image(systemName: "magnifyingglass")
                        .foregroundStyle(.white.opacity(0.5))

                    TextField("Search languages", text: $searchText)
                        .font(.appFont(17, variant: .light))
                        .foregroundStyle(.white)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .focused($isSearchFocused)
                }
                .padding(.horizontal, 16)
                .frame(minHeight: 50)
                .background(AppTheme.cardFill)
                .clipShape(RoundedRectangle(cornerRadius: AppTheme.cardCornerRadius))

                AppCard(
                    contentInsets: EdgeInsets(
                        top: 0,
                        leading: AppTheme.cardPadding,
                        bottom: 4,
                        trailing: AppTheme.cardPadding
                    )
                ) {
                    LazyVStack(spacing: 0) {
                        ForEach(Array(filteredLanguages.enumerated()), id: \.element.id) { index, language in
                            languageButton(language)
                                .disabled(isAdvancing)

                            if index < filteredLanguages.count - 1 {
                                Divider()
                                    .overlay(.white.opacity(0.14))
                            }
                        }

                        if filteredLanguages.isEmpty {
                            Text("No languages found")
                                .font(.appFont(16, variant: .light))
                                .foregroundStyle(.white.opacity(0.6))
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 18)
                        }
                    }
                }
            }
            .padding(.bottom, 92)
        }
        .safeAreaInset(edge: .bottom) {
            AppActionButton(
                title: "Continue",
                style: .primary,
                fillsWidth: true,
                fontSize: 20,
                isEnabled: selection != nil && !isAdvancing,
                action: completeSelection
            )
            .padding(.horizontal, AppTheme.screenPadding)
            .padding(.top, 8)
            .padding(.bottom, 12)
            .background(AppTheme.screenBackground.opacity(0.98))
        }
        .onAppear {
            selection = onboardingStore.onboardingDictationLanguage
        }
        .onDisappear {
            advanceTask?.cancel()
            advanceTask = nil
        }
    }

    private var filteredLanguages: [DictationLanguage] {
        guard !searchText.isEmpty else {
            return whisperLanguages
        }

        return whisperLanguages.filter {
            DictationLanguageDisplayNameFormatter.displayName(for: $0)
                .localizedCaseInsensitiveContains(searchText)
        }
    }

    private var whisperLanguages: [DictationLanguage] {
        let specificLanguages = WhisperBaseLanguageCatalog.supportedLanguages
            .filter { !$0.isAutomatic }
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
            appHaptics.light()
            selection = language
        } label: {
            HStack(spacing: 12) {
                Text(DictationLanguageDisplayNameFormatter.displayName(for: language))
                    .font(.appFont(17))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity, alignment: .leading)

                Image(systemName: selection == language ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 21, weight: .medium))
                    .foregroundStyle(selection == language ? .yellow : .white.opacity(0.3))
            }
            .contentShape(Rectangle())
            .padding(.vertical, 13)
        }
        .buttonStyle(.plain)
    }

    private func completeSelection() {
        guard let selection else { return }

        appHaptics.medium()
        guard isSearchFocused else {
            advance(with: selection)
            return
        }

        isAdvancing = true
        isSearchFocused = false
        advanceTask?.cancel()
        advanceTask = Task { @MainActor in
            defer {
                isAdvancing = false
                advanceTask = nil
            }

            try? await Task.sleep(for: .milliseconds(300))
            guard Task.isCancelled == false else { return }
            advance(with: selection)
        }
    }

    private func advance(with selection: DictationLanguage) {
        settingsStore.whisperDictationLanguage = selection
        onboardingStore.completeLanguageSelection(language: selection)
    }
}
