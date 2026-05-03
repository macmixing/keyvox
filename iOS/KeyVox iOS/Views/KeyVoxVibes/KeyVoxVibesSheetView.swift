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

        static let full = IntroPresentation(displayedScenes: [.a, .b, .c], initialScene: .a)
        static let usageOnly = IntroPresentation(displayedScenes: [.b], initialScene: .b)
    }

    enum Mode {
        case intro(presentation: IntroPresentation = .full, onTryNow: () -> Void, onDismiss: () -> Void)
        case info(presentation: IntroPresentation = .usageOnly, onDismiss: () -> Void)
        case unlock(onDismiss: () -> Void)
    }

    @Environment(\.dismiss) private var dismiss
    @Environment(\.appHaptics) private var appHaptics
    @EnvironmentObject private var vibesPurchaseController: KeyVoxVibesPurchaseController
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
            [.b, .unlock]
        }
    }

    private var initialScene: Scene {
        switch mode {
        case .intro(let presentation, _, _):
            presentation.initialScene
        case .info(let presentation, _):
            presentation.initialScene
        case .unlock:
            .b
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
        }
        .interactiveDismissDisabled()
        .onAppear {
            selectedScene = initialScene
            startButtonAnimation()
        }
        .onDisappear {
            animationTask?.cancel()
            animationTask = nil
            if case .unlock(let onDismiss) = mode {
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
                    title: "Try Now",
                    style: .primary,
                    fillsWidth: true,
                    size: .compact,
                    fontSize: 22,
                    action: onTryNow
                )
            }
            .padding(.horizontal, 20)
            .background(AppTheme.screenBackground)
        case .info:
            EmptyView()
        case .unlock:
            VStack(spacing: 8) {
                AppActionButton(
                    title: purchaseButtonTitle,
                    style: .primary,
                    fillsWidth: true,
                    size: .compact,
                    fontSize: 22,
                    isEnabled: vibesPurchaseController.isStoreActionInFlight == false,
                    action: purchaseUnlock
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
        if vibesPurchaseController.isVibesUnlocked {
            return "Unlocked"
        }

        if let unlockProduct = vibesPurchaseController.unlockProduct {
            return "Unlock \(unlockProduct.displayPrice)"
        }

        return "Unlock"
    }

    @ViewBuilder
    private func sceneView(for scene: Scene) -> some View {
        switch scene {
        case .a:
            KeyVoxVibesSceneAView(isVisible: selectedScene == .a)
        case .b:
            KeyVoxVibesSceneBView(isVisible: selectedScene == .b)
        case .c:
            KeyVoxVibesSceneCView(isVisible: selectedScene == .c)
        case .unlock:
            KeyVoxVibesUnlockScene(isVisible: selectedScene == .unlock)
        }
    }

    private func purchaseUnlock() {
        guard vibesPurchaseController.isVibesUnlocked == false else { return }

        appHaptics.light()
        Task {
            await vibesPurchaseController.purchaseVibesUnlock()
        }
    }

    private func restorePurchases() {
        appHaptics.light()
        Task {
            await vibesPurchaseController.restorePurchases()
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
