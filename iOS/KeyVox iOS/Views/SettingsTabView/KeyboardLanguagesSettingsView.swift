import SwiftUI

/// The keyboard's Languages settings, opened from the Languages row of Keyboard settings: the
/// typing languages, then the letter layout of each. Owns the full-screen language list.
struct KeyboardLanguagesSettingsView: View {
    @EnvironmentObject private var settingsStore: AppSettingsStore
    @State private var isLanguageListPresented = false

    var body: some View {
        let selection = settingsStore.keyboardTypingLanguageSelection
        AppScrollScreen(additionalTopContentInset: AppScreenContentInset.tabPageTop) {
            VStack(alignment: .leading, spacing: AppTheme.sectionSpacing) {
                KeyboardLanguagesCard(selection: selection) {
                    isLanguageListPresented = true
                }
                KeyboardLayoutsCard(selection: selection)
            }
        }
        .navigationTitle(KeyboardLanguagesSettingsCopy.screenTitle)
        .navigationBarTitleDisplayMode(.inline)
        .fullScreenCover(isPresented: $isLanguageListPresented) {
            KeyboardLanguagesScreen(selection: selection) {
                isLanguageListPresented = false
            }
        }
    }
}
