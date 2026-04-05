import SwiftUI

struct TTSUnlockSheetView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.appHaptics) private var appHaptics
    @EnvironmentObject private var ttsPurchaseController: TTSPurchaseController

    var body: some View {
        NavigationStack {
            AppScrollScreen {
                AppCard {
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Unlock TTS")
                            .font(.appFont(20))
                            .foregroundStyle(.white)

                        Text("Keep copied text playback available without the daily free limit.")
                            .font(.appFont(15, variant: .light))
                            .foregroundStyle(.white.opacity(0.78))

                        VStack(alignment: .leading, spacing: 10) {
                            Text("Two free speaks per day")
                            Text("Replay stays free for anything already generated")
                            Text(ttsPurchaseSummaryText)
                        }
                        .font(.appFont(14, variant: .light))
                        .foregroundStyle(.white.opacity(0.7))

                        HStack(spacing: 10) {
                            AppActionButton(
                                title: purchaseButtonTitle,
                                style: .primary,
                                fillsWidth: true,
                                size: .compact,
                                fontSize: 15,
                                isEnabled: ttsPurchaseController.isStoreActionInFlight == false,
                                action: purchaseUnlock
                            )

                            AppActionButton(
                                title: "Restore",
                                style: .secondary,
                                fillsWidth: true,
                                size: .compact,
                                fontSize: 15,
                                isEnabled: ttsPurchaseController.isStoreActionInFlight == false,
                                action: restorePurchases
                            )
                        }

                        if let storeMessage = ttsPurchaseController.storeMessage {
                            Text(storeMessage)
                                .font(.appFont(12))
                                .foregroundStyle(.red)
                        }
                    }
                }
            }
            .navigationTitle("")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        dismissSheet()
                    }
                    .foregroundStyle(.yellow)
                }
            }
        }
    }

    private var purchaseButtonTitle: String {
        if ttsPurchaseController.isTTSUnlocked {
            return "Unlocked"
        }

        if let unlockProduct = ttsPurchaseController.unlockProduct {
            return "Unlock \(unlockProduct.displayPrice)"
        }

        return "Unlock"
    }

    private var ttsPurchaseSummaryText: String {
        ttsPurchaseController.refreshUsageIfNeeded()
        if ttsPurchaseController.isTTSUnlocked {
            return "TTS is unlocked on this Apple account."
        }

        return "\(ttsPurchaseController.remainingFreeTTSSpeaksToday) free speaks left today"
    }

    private func purchaseUnlock() {
        guard ttsPurchaseController.isTTSUnlocked == false else {
            dismissSheet()
            return
        }

        appHaptics.light()
        Task {
            await ttsPurchaseController.purchaseTTSUnlock()
        }
    }

    private func restorePurchases() {
        appHaptics.light()
        Task {
            await ttsPurchaseController.restorePurchases()
        }
    }

    private func dismissSheet() {
        ttsPurchaseController.dismissUnlockSheet()
        dismiss()
    }
}
