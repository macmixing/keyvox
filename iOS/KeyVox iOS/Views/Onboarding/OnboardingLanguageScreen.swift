import Foundation
import KeyVoxCore
import SwiftUI

/// The dictation language picker, in onboarding and opened from Dictation settings: the shared
/// language list with one language checked at a time, Auto Detect first and the rest alphabetical.
struct OnboardingLanguageScreen: View {
    enum PresentationContext {
        case onboarding
        case settings(onDone: () -> Void)
    }

    @Environment(\.appHaptics) private var appHaptics
    @EnvironmentObject private var onboardingStore: OnboardingStore
    @EnvironmentObject private var settingsStore: AppSettingsStore
    @FocusState private var isSearchFocused: Bool
    @State private var selection: DictationLanguage?
    @State private var isAdvancing = false
    @State private var advanceTask: Task<Void, Never>?
    private let presentationContext: PresentationContext

    init(presentationContext: PresentationContext = .onboarding) {
        self.presentationContext = presentationContext
    }

    var body: some View {
        LanguageListScreen(
            options: whisperLanguages.map {
                LanguageListOption(id: $0.rawValue, name: DictationLanguageDisplayNameFormatter.displayName(for: $0))
            },
            selection: .single(Binding(
                get: { selection?.rawValue },
                set: { selection = $0.map(DictationLanguage.init(rawValue:)) }
            )),
            actionTitle: actionTitle,
            isSearchFocused: $isSearchFocused,
            ignoresLanguageTaps: isAdvancing,
            onAction: completeSelection
        ) {
            VStack(alignment: .leading, spacing: 8) {
                Text("Choose your language", comment: "Title of the dictation language picker screen.")
                    .font(.appFont(30))
                    .foregroundStyle(.white)

                Text("We recommend choosing the language you use most for more reliable dictation.", comment: "Advice on the dictation language picker screen.")
                    .font(.appFont(17, variant: .light))
                    .foregroundStyle(.yellow.opacity(0.78))

                Text("Choose Auto Detect for multilingual conversations. You can change this anytime in Settings.", comment: "Advice on the dictation language picker screen. Auto Detect is the name of the language option that detects the spoken language; Settings is the KeyVox app's Settings tab.")
                    .font(.appFont(15, variant: .light))
                    .foregroundStyle(.white.opacity(0.6))
            }
        }
        .onAppear {
            selection = initialSelection
        }
        .onChange(of: onboardingStore.shouldShowLanguageSelectionScreen) { _, shouldShowLanguageSelection in
            guard shouldShowLanguageSelection else { return }
            isAdvancing = false
            advanceTask?.cancel()
            advanceTask = nil
        }
        .onDisappear {
            advanceTask?.cancel()
            advanceTask = nil
        }
    }

    private var actionTitle: String {
        switch presentationContext {
        case .onboarding:
            String(localized: "Continue", comment: "Button on the dictation language picker screen during onboarding that confirms the choice and moves on.")
        case .settings:
            String(localized: "Done", comment: "Button on the dictation language picker screen opened from Settings that confirms the choice.")
        }
    }

    private var initialSelection: DictationLanguage? {
        switch presentationContext {
        case .onboarding:
            onboardingStore.onboardingDictationLanguage
        case .settings:
            settingsStore.whisperDictationLanguage
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

    private func completeSelection() {
        guard let selection, isAdvancing == false else { return }

        appHaptics.medium()
        guard isSearchFocused else {
            advance(with: selection)
            return
        }

        isAdvancing = true
        isSearchFocused = false
        advanceTask?.cancel()
        advanceTask = Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(300))
            guard Task.isCancelled == false else { return }
            advanceTask = nil
            advance(with: selection)
        }
    }

    private func advance(with selection: DictationLanguage) {
        settingsStore.whisperDictationLanguage = selection

        switch presentationContext {
        case .onboarding:
            onboardingStore.completeLanguageSelection(language: selection)
        case .settings(let onDone):
            onDone()
        }
    }
}
