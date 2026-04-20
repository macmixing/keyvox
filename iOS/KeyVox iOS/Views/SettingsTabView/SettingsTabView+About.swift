import StoreKit
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
            Button(action: openGitHubSponsors) {
                VStack(alignment: .leading, spacing: 12) {
                    HStack(alignment: .top, spacing: 12) {
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

                        Image(systemName: "link")
                            .font(.system(size: 18, weight: .bold))
                            .foregroundColor(.yellow)
                            .padding(.top, 2)
                    }

                    Text("Support open source development via GitHub Sponsors.")
                        .font(.appFont(15, variant: .light))
                        .foregroundStyle(.white.opacity(0.7))
                }
            }
            .buttonStyle(.plain)
        }
    }

    @ViewBuilder
    var restorePurchasesSection: some View {
        if ttsPurchaseController.isTTSUnlocked == false {
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
                            isEnabled: ttsPurchaseController.isStoreActionInFlight == false,
                            action: {
                                appHaptics.light()
                                Task {
                                    await ttsPurchaseController.restorePurchases()
                                }
                            }
                        )
                    }

                    Text("Restore past purchases for KeyVox Speak access on this Apple account.")
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
        if #available(iOS 18.0, *) {
            if let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene {
                AppStore.requestReview(in: scene)
            }
        } else {
            if let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene {
                SKStoreReviewController.requestReview(in: scene)
            }
        }
    }

    func openGitHubSponsors() {
        appHaptics.light()
        if let url = URL(string: "https://github.com/sponsors/macmixing/") {
            UIApplication.shared.open(url)
        }
    }

    func presentThirdPartyNotices() {
        appHaptics.light()
        isThirdPartyNoticesPresented = true
    }
}
