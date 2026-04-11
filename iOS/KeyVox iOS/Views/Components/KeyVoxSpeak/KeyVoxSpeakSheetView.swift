import SwiftUI

struct KeyVoxSpeakSheetView: View {
    private enum Scene: Int, CaseIterable {
        case a
        case b
        case c
        case unlock
    }

    enum Mode {
        case intro(onTryNow: () -> Void, onDismiss: () -> Void)
        case unlock(onDismiss: () -> Void)
    }

    @Environment(\.appHaptics) private var appHaptics
    @EnvironmentObject private var pocketTTSModelManager: PocketTTSModelManager
    @EnvironmentObject private var settingsStore: AppSettingsStore
    @EnvironmentObject private var ttsPurchaseController: TTSPurchaseController
    @EnvironmentObject private var ttsPreviewPlayer: TTSPreviewPlayer
    @State private var selectedScene = Scene.a
    @State private var buttonOpacity: Double = 0
    @State private var tabViewOpacity: Double = 0
    @State private var animationTask: Task<Void, Never>?

    let mode: Mode

    private var displayedScenes: [Scene] {
        switch mode {
        case .intro:
            [.a, .b, .c]
        case .unlock:
            if shouldShowSetupSceneInUnlockFlow {
                [.unlock, .b, .c]
            } else {
                [.unlock, .b]
            }
        }
    }

    private var initialScene: Scene {
        switch mode {
        case .intro:
            .a
        case .unlock:
            .unlock
        }
    }

    private var shouldShowSetupSceneInUnlockFlow: Bool {
        guard case .unlock = mode else { return false }
        return pocketTTSModelManager.isReady(for: settingsStore.ttsVoice) == false
    }

    var body: some View {
        NavigationStack {
            ZStack {
                AppTheme.screenBackground
                    .ignoresSafeArea()

                VStack(spacing: 0) {
                    TabView(selection: $selectedScene) {
                        ForEach(displayedScenes, id: \.self) { scene in
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
                        case .intro(let onTryNow, _):
                            AppActionButton(
                                title: "Try KeyVox Speak",
                                style: .primary,
                                fillsWidth: true,
                                size: .compact,
                                fontSize: 22,
                                action: onTryNow
                            )
                        case .unlock:
                            AppActionButton(
                                title: purchaseButtonTitle,
                                style: .primary,
                                fillsWidth: true,
                                size: .compact,
                                fontSize: 22,
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
                    .background(AppTheme.screenBackground)
                    .opacity(buttonOpacity)
                }

                VStack {
                    HStack {
                        Spacer()

                        Button(action: dismissSheet) {
                            Image(systemName: "xmark")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundStyle(.white.opacity(0.58))
                                .frame(width: 28, height: 28)
                                .contentShape(Rectangle())
                        }
                        .accessibilityLabel("Close")
                        .buttonStyle(.plain)
                        .padding(.top, 10)
                        .padding(.trailing, 12)
                    }

                    Spacer()
                }
            }
            .navigationTitle("")
        }
        .interactiveDismissDisabled()
        .onAppear {
            selectedScene = initialScene
            startButtonAnimation()
        }
        .onDisappear {
            ttsPreviewPlayer.stop()
            animationTask?.cancel()
            animationTask = nil
            
            if case .unlock(let onDismiss) = mode {
                onDismiss()
            }
        }
    }

    private var isUnlockMode: Bool {
        if case .unlock = mode { return true }
        return false
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

    @ViewBuilder
    private func sceneView(for scene: Scene) -> some View {
        switch scene {
        case .a:
            KeyVoxSpeakSceneAView(isVisible: selectedScene == .a)
        case .b:
            KeyVoxSpeakSceneBView(isVisible: selectedScene == .b, isUnlockContext: isUnlockMode)
        case .c:
            KeyVoxSpeakSceneCView(
                isVisible: selectedScene == .c,
                isUnlockContext: isUnlockMode
            )
        case .unlock:
            KeyVoxSpeakUnlockScene(isVisible: selectedScene == .unlock)
        }
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

    private func dismissSheet() {
        switch mode {
        case .intro(_, let onDismiss):
            onDismiss()
        case .unlock(let onDismiss):
            onDismiss()
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
