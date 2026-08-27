import KeyVoxPromotions
import SwiftUI

struct IOSPromotionCard: View {
    let campaign: PromotionCampaign
    @Environment(\.openURL) private var openURL

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .center, spacing: 12) {
                iconView

                Text(campaign.title)
                    .font(.appFont(18))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity, alignment: .leading)

                if let sharing = campaign.sharing {
                    shareButton(for: sharing)
                }
            }

            Text(campaign.message)
                .font(.appFont(15, variant: .light))
                .foregroundStyle(.white.opacity(0.7))
                .frame(maxWidth: .infinity, alignment: .leading)

            if let buttonTitle = campaign.buttonTitle,
               let action = campaign.action {
                AppActionButton(
                    title: buttonTitle,
                    style: .primary,
                    fillsWidth: true
                ) {
                    openURL(action.url)
                }
            }
        }
        .padding(AppTheme.cardPadding)
        .background(
            RoundedRectangle(cornerRadius: AppTheme.cardCornerRadius)
                .fill(Color.yellow.opacity(0.14))
                .overlay(
                    RoundedRectangle(cornerRadius: AppTheme.cardCornerRadius)
                        .stroke(Color.yellow.opacity(0.32), lineWidth: 1)
                )
        )
        .animation(.easeInOut(duration: 0.2), value: campaign.id)
    }

    @ViewBuilder
    private var iconView: some View {
        ZStack {
            ZStack {
                Circle()
                    .fill(AppTheme.screenBackground)
                Circle()
                    .fill(AppTheme.cardFill)
                Circle()
                    .fill(AppTheme.accent.opacity(0.4))
            }
            .frame(width: 32, height: 32)

            switch campaign.icon.kind {
            case .systemImage:
                Image(systemName: campaign.icon.name ?? "sparkles")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(.yellow)
            case .appBundleIcon:
                Image("keyvox-circle")
                    .resizable()
                    .renderingMode(.template)
                    .foregroundStyle(.white)
                    .scaledToFit()
                    .frame(width: 20, height: 20)
            case .asset:
                Image(campaign.icon.name ?? "")
                    .resizable()
                    .renderingMode(.template)
                    .foregroundStyle(.yellow)
                    .scaledToFit()
                    .frame(width: 16, height: 16)
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
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(Color.white.opacity(0.48))
                .frame(width: 44, height: 44)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Share \(campaign.title)")
        .padding(.trailing, -8)
    }
}
