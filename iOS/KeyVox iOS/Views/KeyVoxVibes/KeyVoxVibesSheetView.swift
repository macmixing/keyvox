import KeyVoxStyleRewrite
import SwiftUI

struct KeyVoxVibesSheetView: View {
    enum Scene: Int, CaseIterable, Equatable, Hashable {
        case a
        case b
        case c
        case unlock
    }

    struct IntroPresentation: Equatable {
        let displayedScenes: [Scene]
        let initialScene: Scene
        let sceneCVariant: SceneCVariant

        static let full = IntroPresentation(displayedScenes: [.a, .b, .c], initialScene: .a)
        static let usageOnly = IntroPresentation(displayedScenes: [.b], initialScene: .b)
        static let trialStart = IntroPresentation(displayedScenes: [.a, .b, .c], initialScene: .c)
        static let activeTrialRecovery = IntroPresentation(
            displayedScenes: [.a, .b, .c],
            initialScene: .c,
            sceneCVariant: .activeTrialRecovery
        )

        init(
            displayedScenes: [Scene],
            initialScene: Scene,
            sceneCVariant: SceneCVariant = .standard
        ) {
            self.displayedScenes = displayedScenes
            self.initialScene = initialScene
            self.sceneCVariant = sceneCVariant
        }
    }

    enum SceneCVariant: Equatable {
        case standard
        case activeTrialRecovery
    }

    enum Mode {
        case intro(presentation: IntroPresentation = .full, onTryNow: () -> Void, onDismiss: () -> Void)
        case info(presentation: IntroPresentation = .usageOnly, onDismiss: () -> Void)
        case unlock(initialScene: Scene = .unlock, primaryAction: UnlockPrimaryAction = .purchase, onDismiss: () -> Void)
    }

    enum UnlockPrimaryAction: Equatable {
        case purchase
        case continueWhenVibesAIReady
    }

    @Environment(\.dismiss) private var dismiss
    @Environment(\.appHaptics) private var appHaptics
    @EnvironmentObject private var settingsStore: AppSettingsStore
    @EnvironmentObject private var vibesPurchaseController: KeyVoxVibesPurchaseController
    @EnvironmentObject private var localRewriteModelManager: LocalRewriteModelManager
    @State private var pendingDownloadConfirmation: PendingDownloadConfirmation?
    @State private var selectedScene = Scene.a
    @State private var buttonOpacity: Double = 0
    @State private var tabViewOpacity: Double = 0
    @State private var animationTask: Task<Void, Never>?

    let mode: Mode

    private var displayedScenes: [Scene] {
        switch mode {
        case .intro(let presentation, _, _):
            presentation.displayedScenes
        case .info(let presentation, _):
            presentation.displayedScenes
        case .unlock:
            [.unlock, .b]
        }
    }

    private var initialScene: Scene {
        switch mode {
        case .intro(let presentation, _, _):
            presentation.initialScene
        case .info(let presentation, _):
            presentation.initialScene
        case .unlock(let initialScene, _, _):
            initialScene
        }
    }

    private var sceneCVariant: SceneCVariant {
        switch mode {
        case .intro(let presentation, _, _), .info(let presentation, _):
            presentation.sceneCVariant
        case .unlock:
            .standard
        }
    }

    private var pageIndexDisplayMode: PageTabViewStyle.IndexDisplayMode {
        displayedScenes.count > 1 ? .always : .never
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
                    .tabViewStyle(.page(indexDisplayMode: pageIndexDisplayMode))
                    .opacity(tabViewOpacity)

                    bottomActions
                        .opacity(buttonOpacity)
                }

                VStack {
                    HStack {
                        Spacer()

                        Button(action: dismissSheet) {
                            Image(systemName: "xmark")
                                .font(.system(size: 18, weight: .semibold))
                                .foregroundStyle(.white.opacity(0.58))
                                .frame(width: 36, height: 36)
                                .contentShape(Rectangle())
                        }
                        .accessibilityLabel("Close")
                        .buttonStyle(.plain)
                        .padding(.top, 7)
                        .padding(.trailing, 7)
                    }

                    Spacer()
                }
            }
            .navigationTitle("")
            .downloadConfirmation($pendingDownloadConfirmation, onConfirm: performDownloadConfirmation)
        }
        .interactiveDismissDisabled()
        .onAppear {
            selectedScene = initialScene
            startButtonAnimation()
        }
        .onDisappear {
            animationTask?.cancel()
            animationTask = nil
            if case .unlock(_, _, let onDismiss) = mode {
                onDismiss()
            } else if case .info(_, let onDismiss) = mode {
                onDismiss()
            }
        }
    }

    @ViewBuilder
    private var bottomActions: some View {
        switch mode {
        case .intro(_, let onTryNow, _):
            VStack(spacing: 8) {
                AppActionButton(
                    title: introActionTitle,
                    style: .primary,
                    fillsWidth: true,
                    size: .compact,
                    fontSize: 22,
                    isEnabled: isIntroActionEnabled,
                    action: {
                        handleIntroAction(onTryNow: onTryNow)
                    }
                )
            }
            .padding(.horizontal, 20)
            .background(AppTheme.screenBackground)
        case .info:
            VStack(spacing: 8) {
                AppActionButton(
                    title: "Vibe Now",
                    style: .primary,
                    fillsWidth: true,
                    size: .compact,
                    fontSize: 22,
                    action: dismissSheet
                )
            }
            .padding(.horizontal, 20)
            .background(AppTheme.screenBackground)
        case .unlock:
            VStack(spacing: 8) {
                AppActionButton(
                    title: purchaseButtonTitle,
                    style: .primary,
                    fillsWidth: true,
                    size: .compact,
                    fontSize: 22,
                    isEnabled: isUnlockPrimaryActionEnabled,
                    action: handleUnlockPrimaryAction
                )

                Button(action: restorePurchases) {
                    Text("Restore Purchases")
                        .font(.appFont(14, variant: .light))
                        .foregroundStyle(.white.opacity(0.8))
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.plain)
                .disabled(vibesPurchaseController.isStoreActionInFlight)
            }
            .padding(.horizontal, 20)
            .background(AppTheme.screenBackground)
        }
    }

    private var purchaseButtonTitle: String {
        if unlockPrimaryAction == .continueWhenVibesAIReady {
            return "Continue"
        }

        if vibesPurchaseController.isVibesUnlocked {
            return "Unlocked"
        }

        if let unlockProduct = vibesPurchaseController.unlockProduct {
            return "Unlock \(unlockProduct.displayPrice)"
        }

        return "Unlock"
    }

    private var unlockPrimaryAction: UnlockPrimaryAction {
        if case .unlock(_, let primaryAction, _) = mode {
            return primaryAction
        }

        return .purchase
    }

    private var isUnlockPrimaryActionEnabled: Bool {
        switch unlockPrimaryAction {
        case .purchase:
            return vibesPurchaseController.isStoreActionInFlight == false
        case .continueWhenVibesAIReady:
            return isVibesAIReady
        }
    }

    private var isVibesAIReady: Bool {
        localRewriteModelManager.isModelReady()
    }

    private var introActionTitle: String {
        guard isVibesAIReady == false else {
            return "Try Now"
        }

        switch selectedScene {
        case .a:
            return "Get Started"
        case .b:
            return "Next"
        case .c, .unlock:
            return "Try Now"
        }
    }

    private var isIntroActionEnabled: Bool {
        isVibesAIReady || selectedScene != .c
    }

    private func handleIntroAction(onTryNow: () -> Void) {
        guard isVibesAIReady == false else {
            onTryNow()
            return
        }

        switch selectedScene {
        case .a:
            advanceIntro(to: .b)
        case .b:
            advanceIntro(to: .c)
        case .c, .unlock:
            break
        }
    }

    private func advanceIntro(to scene: Scene) {
        guard displayedScenes.contains(scene) else { return }
        appHaptics.light()
        withAnimation(.easeInOut(duration: 0.22)) {
            selectedScene = scene
        }
    }

    @ViewBuilder
    private func sceneView(for scene: Scene) -> some View {
        switch scene {
        case .a:
            KeyVoxVibesSceneAView(
                isVisible: selectedScene == .a,
                dictationModel: settingsStore.activeDictationProvider.styleRewriteDictationModel
            )
        case .b:
            KeyVoxVibesSceneBView(isVisible: selectedScene == .b)
        case .c:
            KeyVoxVibesSceneCView(
                isVisible: selectedScene == .c,
                variant: sceneCVariant,
                onDownloadRequested: { pendingDownloadConfirmation = $0 }
            )
        case .unlock:
            KeyVoxVibesUnlockScene(
                isVisible: selectedScene == .unlock,
                onDownloadRequested: { pendingDownloadConfirmation = $0 }
            )
        }
    }

    private func purchaseUnlock() {
        guard vibesPurchaseController.isVibesUnlocked == false else { return }

        appHaptics.light()
        Task {
            await vibesPurchaseController.purchaseVibesUnlock()
        }
    }

    private func handleUnlockPrimaryAction() {
        switch unlockPrimaryAction {
        case .purchase:
            purchaseUnlock()
        case .continueWhenVibesAIReady:
            guard isVibesAIReady else { return }
            dismissSheet()
        }
    }

    private func restorePurchases() {
        appHaptics.light()
        Task {
            await vibesPurchaseController.restorePurchases()
        }
    }

    private func performDownloadConfirmation(_ confirmation: PendingDownloadConfirmation) {
        switch confirmation {
        case .keyVoxVibesAI:
            localRewriteModelManager.downloadModel()
        case .dictationModel, .sharedTTSModel, .ttsVoice, .ttsVoiceWithSharedModel:
            break
        }
    }

    private func dismissSheet() {
        appHaptics.light()
        switch mode {
        case .intro(_, _, let onDismiss):
            onDismiss()
        case .info, .unlock:
            dismiss()
        }
    }

    private func startButtonAnimation() {
        buttonOpacity = 0
        tabViewOpacity = 0
        animationTask?.cancel()

        animationTask = Task { @MainActor in
            do {
                try await Task.sleep(for: .seconds(0.2))

                withAnimation(.easeIn(duration: 0.4)) {
                    tabViewOpacity = 1
                }

                try await Task.sleep(for: .seconds(0.5))

                withAnimation(.easeIn(duration: 0.4)) {
                    buttonOpacity = 1
                }
            } catch is CancellationError {
                return
            } catch {
                return
            }
        }
    }
}
