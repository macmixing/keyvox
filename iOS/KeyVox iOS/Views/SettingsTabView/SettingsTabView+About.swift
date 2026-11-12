import Foundation
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

                    Text("Rate & Review", comment: "Title of the Settings card that asks the user to rate the app.")
                        .font(.appFont(18))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    AppActionButton(
                        title: String(localized: "Rate", comment: "Button on the Rate & Review card that opens the App Store review page."),
                        style: .primary,
                        size: .compact,
                        fontSize: 15,
                        action: openAppStoreReview
                    )
                }

                Text("Share your experience on the App Store.", comment: "Description on the Rate & Review card. Use Apple's official name for the App Store in this language.")
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

                    Text("Support on GitHub", comment: "Title of the Settings card for sponsoring the project. GitHub is a product name and stays in English.")
                        .font(.appFont(18))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    AppActionButton(
                        title: String(localized: "Open", comment: "Button on the Support on GitHub card that opens the sponsor page."),
                        style: .primary,
                        size: .compact,
                        fontSize: 15,
                        action: openGitHubSponsors
                    )
                }

                Text("Support open source development via GitHub Sponsors.", comment: "Description on the Support on GitHub card. GitHub Sponsors is a product name and stays in English.")
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

                    Text("Need Help?", comment: "Title of the Settings card that opens the KeyVox help and FAQ page.")
                        .font(.appFont(18))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    AppActionButton(
                        title: String(localized: "Open", comment: "Button on the Need Help? card that opens the help and FAQ page."),
                        style: .primary,
                        size: .compact,
                        fontSize: 15,
                        action: openHelpFAQ
                    )
                }

                Text("Get help with KeyVox, download the Mac app, read the FAQ, find more information, or contact us.", comment: "Description on the Need Help? card. KeyVox is a brand name and stays in English; use Apple's official name for Mac in this language.")
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

                        Text("Restore Purchases", comment: "Title of the Settings card for restoring earlier in-app purchases. Use the term Apple uses for restoring purchases in this language.")
                            .font(.appFont(18))
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity, alignment: .leading)

                        AppActionButton(
                            title: String(localized: "Restore", comment: "Button on the Restore Purchases card that restores earlier in-app purchases."),
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

                    Text("Restore past purchases for KeyVox Speak and KeyVox Vibes access on this Apple account.", comment: "Description on the Restore Purchases card. KeyVox Speak and KeyVox Vibes are brand names and stay in English; use Apple's official term for Apple Account in this language.")
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
                    Text("Third-Party Notices", comment: "Button at the bottom of Settings that opens the open source license notices.")
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
