import AppKit
import Foundation
import KeyVoxPromotions
import SwiftUI

struct MacPromotionCard: View {
    let campaign: PromotionCampaign

    /// The campaign wording in the language the app is showing.
    private var copy: PromotionCopy {
        campaign.copy(forLanguage: Bundle.main.preferredLocalizations.first)
    }

    var body: some View {
        SettingsCard(
            fillColor: MacAppTheme.promoCardFill,
            strokeColor: MacAppTheme.promoCardStroke
        ) {
            VStack(alignment: .leading, spacing: 14) {
                HStack(alignment: .center, spacing: 12) {
                    iconView

                    Text(copy.title)
                        .font(.appFont(16))
                        .lineLimit(1)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    if let sharing = campaign.sharing {
                        shareButton(for: sharing)
                    }
                }

                HStack(alignment: .center, spacing: 16) {
                    Text(copy.message)
                        .font(.appFont(13, variant: .light))
                        .foregroundColor(.primary)
                        .lineSpacing(2)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    if let buttonTitle = copy.buttonTitle,
                       let action = campaign.action {
                        AppActionButton(
                            title: buttonTitle,
                            style: .primary,
                            minWidth: 96
                        ) {
                            NSWorkspace.shared.open(action.url)
                        }
                    }
                }
            }
        }
        .animation(.easeInOut(duration: 0.2), value: campaign.id)
    }

    @ViewBuilder
    private var iconView: some View {
        ZStack {
            ZStack {
                Circle()
                    .fill(MacAppTheme.screenBackground)
                Circle()
                    .fill(MacAppTheme.cardFill)
                Circle()
                    .fill(MacAppTheme.iconFill)
            }
            .frame(width: 44, height: 44)

            switch campaign.icon.kind {
            case .systemImage:
                Image(systemName: campaign.icon.name ?? "sparkles")
                    .font(.appFont(20))
                    .foregroundColor(.yellow)
            case .appBundleIcon:
                Image("logo-white")
                    .resizable()
                    .renderingMode(.template)
                    .foregroundStyle(.white)
                    .scaledToFit()
                    .frame(width: 24, height: 24)
            case .asset:
                Image(campaign.icon.name ?? "")
                    .resizable()
                    .renderingMode(.template)
                    .foregroundStyle(.yellow)
                    .scaledToFit()
                    .frame(width: 24, height: 24)
            }
        }
        .accessibilityHidden(true)
    }

    private func shareButton(for sharing: PromotionSharing) -> some View {
        ShareLink(
            item: sharing.url,
            subject: Text(copy.sharingTitle ?? copy.title),
            message: Text(copy.message)
        ) {
            Image(systemName: "square.and.arrow.up")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: 44, height: 44)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(String(localized: "Share \(copy.title)", comment: "VoiceOver label for the share button on a promotion card in Settings. %@ is the promotion's title."))
    }
}
