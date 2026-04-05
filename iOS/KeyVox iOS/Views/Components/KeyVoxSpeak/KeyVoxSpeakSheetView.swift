import SwiftUI

struct KeyVoxSpeakSheetView: View {
    private enum Scene: Int, CaseIterable {
        case a
        case b
        case c
    }

    enum Mode {
        case intro(onTryNow: () -> Void)
        case unlock(onDismiss: () -> Void)
    }

    @Environment(\.appHaptics) private var appHaptics
    @EnvironmentObject private var ttsPurchaseController: TTSPurchaseController
    @EnvironmentObject private var ttsPreviewPlayer: TTSPreviewPlayer
    @State private var selectedScene = Scene.a
    @State private var buttonOpacity: Double = 0
    @State private var tabViewOpacity: Double = 0
    @State private var animationTask: Task<Void, Never>?

    let mode: Mode

    var body: some View {
        NavigationStack {
            ZStack {
                AppTheme.screenBackground
                    .ignoresSafeArea()

                VStack(spacing: 0) {
                    TabView(selection: $selectedScene) {
                        ForEach(Scene.allCases, id: \.self) { scene in
                            sceneView(for: scene)
                                .tag(scene)
                        }
                    }
                    .tabViewStyle(.page(indexDisplayMode: .always))
                    .opacity(tabViewOpacity)

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
                    .opacity(buttonOpacity)
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
        .onAppear {
            startButtonAnimation()
        }
        .onDisappear {
            ttsPreviewPlayer.stop()
            animationTask?.cancel()
            animationTask = nil
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

    @ViewBuilder
    private func sceneView(for scene: Scene) -> some View {
        switch scene {
        case .a:
            KeyVoxSpeakSceneAView()
        case .b:
            KeyVoxSpeakSceneBView()
        case .c:
            KeyVoxSpeakSceneCView(
                showsUnlockDetails: showsUnlockDetails,
                purchaseSummaryText: ttsPurchaseSummaryText,
                isVisible: selectedScene == .c
            )
        }
    }

    private var showsUnlockDetails: Bool {
        if case .unlock = mode {
            return true
        }

        return false
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

    private func startButtonAnimation() {
        buttonOpacity = 0
        tabViewOpacity = 0
        animationTask?.cancel()

        animationTask = Task { @MainActor in
            try? await Task.sleep(for: .seconds(0.2))
            guard !Task.isCancelled else { return }

            withAnimation(.easeIn(duration: 0.4)) {
                tabViewOpacity = 1.0
            }

            try? await Task.sleep(for: .seconds(0.5))
            guard !Task.isCancelled else { return }

            withAnimation(.easeIn(duration: 0.4)) {
                buttonOpacity = 1.0
            }
        }
    }
}
