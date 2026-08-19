import KeyVoxStyleRewrite
import SwiftUI

struct StyleTabView: View {
    @Environment(\.appHaptics) var appHaptics
    @EnvironmentObject var settingsStore: AppSettingsStore
    @EnvironmentObject var keyVoxVibesPurchaseController: KeyVoxVibesPurchaseController
    @EnvironmentObject var localRewriteModelManager: LocalRewriteModelManager
    @State var isVibeExamplesExpanded = false
    @State var vibeExamplesExpandedContentHeight: CGFloat = 0

    static let sectionExpansionAnimation = Animation.spring(response: 0.42, dampingFraction: 0.84)

    var body: some View {
        AppScrollScreen(additionalTopContentInset: AppScreenContentInset.tabPageTop) {
            VStack(alignment: .leading, spacing: 16) {
                keyVoxVibesSection

                AppCard {
                    SettingsRow(
                        icon: "list.number",
                        title: "Lists",
                        description: "Format spoken numbered lists automatically when detected.",
                        isOn: $settingsStore.listFormattingEnabled
                    )
                }
                
                AppCard {
                    SettingsRow(
                        icon: "text.alignleft",
                        title: "Paragraphs",
                        description: "Start new paragraphs automatically after brief pauses in multiline fields.",
                        isOn: $settingsStore.autoParagraphsEnabled
                    )
                }
            }
        }
        .onAppear {
            keyVoxVibesPurchaseController.refreshTrialStateIfNeeded()
        }
    }
}

#Preview {
    StyleTabView()
        .environmentObject(AppServiceRegistry.shared.settingsStore)
        .environmentObject(AppServiceRegistry.shared.keyVoxVibesPurchaseController)
        .environmentObject(AppServiceRegistry.shared.localRewriteModelManager)
}
