import SwiftUI

struct KeyVoxSpeakSheetView: View {
    private struct IntroPage: Identifiable {
        let id: Int
        let title: String
        let body: String
    }

    enum Mode {
        case intro(onTryNow: () -> Void)
        case unlock(onDismiss: () -> Void)
    }

    @Environment(\.appHaptics) private var appHaptics
    @EnvironmentObject private var ttsPurchaseController: TTSPurchaseController
    @State private var selectedPage = 0

    let mode: Mode

    private let pages = [
        IntroPage(
            id: 0,
            title: "KeyVox Speak",
            body: "A new copied-text playback feature is now available in KeyVox."
        ),
        IntroPage(
            id: 1,
            title: "Listen Anywhere",
            body: "Speak copied text from the app and jump back into replay whenever you want to hear it again."
        ),
        IntroPage(
            id: 2,
            title: "Designed To Grow",
            body: "This intro is intentionally lightweight for now while the final KeyVox Speak presentation is still being designed."
        )
    ]

    var body: some View {
        NavigationStack {
            ZStack {
                AppTheme.screenBackground
                    .ignoresSafeArea()

                VStack(spacing: 0) {
                    TabView(selection: $selectedPage) {
                        ForEach(pages) { page in
                            VStack(alignment: .leading, spacing: 16) {
                                Text(page.title)
                                    .font(.appFont(26))
                                    .foregroundStyle(.white)

                                Text(page.body)
                                    .font(.appFont(16, variant: .light))
                                    .foregroundStyle(.white.opacity(0.78))

                                if case .unlock = mode {
                                    VStack(alignment: .leading, spacing: 10) {
                                        Text("Two free speaks per day")
                                        Text("Replay stays free for anything already generated")
                                        Text(ttsPurchaseSummaryText)
                                    }
                                    .font(.appFont(14, variant: .light))
                                    .foregroundStyle(.white.opacity(0.7))
                                    .padding(.top, 8)
                                }

                                Spacer(minLength: 0)
                            }
                            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                            .padding(.horizontal, 24)
                            .padding(.top, 24)
                            .padding(.bottom, 24)
                            .tag(page.id)
                        }
                    }
                    .tabViewStyle(.page(indexDisplayMode: .always))

                    VStack(spacing: 8) {
                        Divider()
                            .background(.white.opacity(0.14))

                        switch mode {
                        case .intro(let onTryNow):
                            AppActionButton(
                                title: "Try KeyVox Speak",
                                style: .primary,
                                fillsWidth: true,
                                size: .compact,
                                fontSize: 15,
                                action: onTryNow
                            )
                        case .unlock:
                            AppActionButton(
                                title: purchaseButtonTitle,
                                style: .primary,
                                fillsWidth: true,
                                size: .compact,
                                fontSize: 15,
                                isEnabled: ttsPurchaseController.isStoreActionInFlight == false,
                                action: purchaseUnlock
                            )

                            Button(action: restorePurchases) {
                                Text("Restore Purchases")
                                    .font(.appFont(14, variant: .light))
                                    .foregroundStyle(.white.opacity(0.8))
                                    .frame(maxWidth: .infinity)
                            }
                            .buttonStyle(.plain)
                            .disabled(ttsPurchaseController.isStoreActionInFlight)
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 16)
                    .background(AppTheme.screenBackground)
                }
            }
            .navigationTitle("")
            .toolbar {
                if case .unlock(let onDismiss) = mode {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button("Done") {
                            onDismiss()
                        }
                        .foregroundStyle(.yellow)
                    }
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
        if ttsPurchaseController.isTTSUnlocked {
            return "TTS is unlocked on this Apple account."
        }

        let remainingFreeSpeaks = ttsPurchaseController.remainingFreeTTSSpeaksToday
        let noun = remainingFreeSpeaks == 1 ? "speak" : "speaks"
        return "\(remainingFreeSpeaks) free \(noun) left today"
    }

    private func purchaseUnlock() {
        guard ttsPurchaseController.isTTSUnlocked == false else { return }

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
}
