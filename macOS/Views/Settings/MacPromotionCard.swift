import AppKit
import KeyVoxPromotions
import SwiftUI

struct MacPromotionCard: View {
    let campaign: PromotionCampaign

    var body: some View {
        SettingsCard(
            fillColor: MacAppTheme.promoCardFill,
            strokeColor: MacAppTheme.promoCardStroke
        ) {
            VStack(alignment: .leading, spacing: 14) {
                HStack(alignment: .center, spacing: 12) {
                    iconView

                    Text(campaign.title)
                        .font(.appFont(16))
                        .lineLimit(1)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    if let sharing = campaign.sharing {
                        shareButton(for: sharing)
                    }
                }

                HStack(alignment: .center, spacing: 16) {
                    Text(campaign.message)
                        .font(.appFont(13))
                        .foregroundColor(.secondary)
                        .lineSpacing(2)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    if let buttonTitle = campaign.buttonTitle,
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
            subject: Text(sharing.title ?? campaign.title),
            message: Text(campaign.message)
        ) {
            Image(systemName: "square.and.arrow.up")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(Color.white.opacity(0.46))
                .frame(width: 44, height: 44)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Share \(campaign.title)")
    }
}
