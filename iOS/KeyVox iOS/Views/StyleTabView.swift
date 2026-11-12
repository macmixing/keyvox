import Foundation
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
                        title: String(localized: "Lists", comment: "Style tab toggle that formats spoken numbered lists."),
                        description: String(localized: "Format spoken numbered lists automatically when detected.", comment: "Description under the Lists toggle on the Style tab."),
                        isOn: $settingsStore.listFormattingEnabled
                    )
                }
                
                AppCard {
                    SettingsRow(
                        icon: "text.alignleft",
                        title: String(localized: "Paragraphs", comment: "Style tab toggle that starts new paragraphs after pauses."),
                        description: String(localized: "Start new paragraphs automatically after brief pauses in multiline fields.", comment: "Description under the Paragraphs toggle on the Style tab."),
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
