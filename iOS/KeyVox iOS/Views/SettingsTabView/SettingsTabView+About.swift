import SwiftUI

extension SettingsTabView {
    @ViewBuilder
    var rateAndReviewSection: some View {
        AppCard {
            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .center, spacing: 12) {
                    ZStack {
                        Circle()
                            .fill(AppTheme.accent.opacity(0.4))
                            .frame(width: 32, height: 32)

                        Image(systemName: "star.fill")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(.yellow)
                    }

                    Text("Rate & Review")
                        .font(.appFont(18))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    AppActionButton(
                        title: "Rate",
                        style: .primary,
                        size: .compact,
                        fontSize: 15,
                        action: openAppStoreReview
                    )
                }

                Text("Share your experience on the App Store.")
                    .font(.appFont(15, variant: .light))
                    .foregroundStyle(.white.opacity(0.7))
            }
        }
    }

    @ViewBuilder
    var supportSection: some View {
        AppCard {
            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .center, spacing: 12) {
                    ZStack {
                        Circle()
                            .fill(AppTheme.accent.opacity(0.4))
                            .frame(width: 32, height: 32)

                        Image("github")
                            .resizable()
                            .renderingMode(.template)
                            .foregroundColor(.yellow.opacity(0.8))
                            .frame(width: 32, height: 32)
                    }

                    Text("Support on GitHub")
                        .font(.appFont(18))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    AppActionButton(
                        title: "Open",
                        style: .primary,
                        size: .compact,
                        fontSize: 15,
                        action: openGitHubSponsors
                    )
                }

                Text("Support open source development via GitHub Sponsors.")
                    .font(.appFont(15, variant: .light))
                    .foregroundStyle(.white.opacity(0.7))
            }
        }
    }

    @ViewBuilder
    var helpSection: some View {
        AppCard {
            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .center, spacing: 12) {
                    ZStack {
                        Circle()
                            .fill(AppTheme.accent.opacity(0.4))
                            .frame(width: 32, height: 32)

                        Image(systemName: "questionmark.circle.fill")
                            .font(.system(size: 32, weight: .medium))
                            .foregroundColor(.yellow.opacity(0.8))
                            .frame(width: 32, height: 32)
                    }

                    Text("Need Help?")
                        .font(.appFont(18))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    AppActionButton(
                        title: "Open",
                        style: .primary,
                        size: .compact,
                        fontSize: 15,
                        action: openHelpFAQ
                    )
                }

                Text("Get help with KeyVox, download the Mac app, read the FAQ, find more information, or contact us.")
                    .font(.appFont(15, variant: .light))
                    .foregroundStyle(.white.opacity(0.7))
            }
        }
    }

    @ViewBuilder
    var restorePurchasesSection: some View {
        if ttsPurchaseController.isTTSUnlocked == false || keyVoxVibesPurchaseController.isVibesUnlocked == false {
            AppCard {
                VStack(alignment: .leading, spacing: 12) {
                    HStack(alignment: .center, spacing: 12) {
                        ZStack {
                            Circle()
                                .fill(AppTheme.accent.opacity(0.4))
                                .frame(width: 32, height: 32)

                            Image(systemName: "arrow.triangle.2.circlepath")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(.yellow)
                        }

                        Text("Restore Purchases")
                            .font(.appFont(18))
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity, alignment: .leading)

                        AppActionButton(
                            title: "Restore",
                            style: .secondary,
                            size: .compact,
                            fontSize: 15,
                            isEnabled: ttsPurchaseController.isStoreActionInFlight == false
                                && keyVoxVibesPurchaseController.isStoreActionInFlight == false,
                            action: {
                                appHaptics.light()
                                Task {
                                    await ttsPurchaseController.restorePurchases()
                                    await keyVoxVibesPurchaseController.restorePurchases()
                                }
                            }
                        )
                    }

                    Text("Restore past purchases for KeyVox Speak and KeyVox Vibes access on this Apple account.")
                        .font(.appFont(15, variant: .light))
                        .foregroundStyle(.white.opacity(0.7))
                }
            }
        }
    }

    @ViewBuilder
    var versionFooter: some View {
        if let appVersionBuildText {
            VStack(spacing: 10) {
                Button(action: presentThirdPartyNotices) {
                    Text("Third-Party Notices")
                        .font(.appFont(14))
                        .foregroundStyle(AppTheme.accent.opacity(0.95))
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.plain)

                Text(appVersionBuildText)
                    .font(.appFont(12))
                    .foregroundStyle(.white.opacity(0.5))
                    .frame(maxWidth: .infinity)
            }
            .padding(.bottom, 12)
        }
    }

    func openAppStoreReview() {
        appHaptics.light()

        var components = URLComponents(
            url: AppUpdateConfiguration.fallbackAppStoreURL,
            resolvingAgainstBaseURL: false
        )
        components?.queryItems = [URLQueryItem(name: "action", value: "write-review")]

        guard let writeReviewURL = components?.url else { return }
        openURL(writeReviewURL)
    }

    func openGitHubSponsors() {
        appHaptics.light()
        if let url = URL(string: "https://github.com/sponsors/macmixing/") {
            UIApplication.shared.open(url)
        }
    }

    func openHelpFAQ() {
        appHaptics.light()
        if let url = URL(string: "https://keyvox.app/?utm_source=keyvox_ios&utm_medium=settings&utm_campaign=help_card#faq") {
            UIApplication.shared.open(url)
        }
    }

    func presentThirdPartyNotices() {
        appHaptics.light()
        isThirdPartyNoticesPresented = true
    }
}
