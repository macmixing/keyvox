import KeyVoxStyleRewrite
import SwiftUI

struct MacVibesIntroWindowView: View {
    private struct ContentSizePreferenceKey: PreferenceKey {
        static var defaultValue: CGSize = .zero

        static func reduce(value: inout CGSize, nextValue: () -> CGSize) {
            let next = nextValue()
            guard next != .zero else { return }
            value = next
        }
    }

    @ObservedObject var localRewriteModelManager: MacLocalRewriteModelManager
    let initialScene: MacVibesIntroScene
    let dictationModel: StyleRewriteDictationModel
    let onPreferredSizeChange: (CGSize) -> Void
    let onDismiss: () -> Void
    let onTryIt: () -> Void

    @State private var selectedScene: MacVibesIntroScene
    @State private var contentOpacity: Double = 0
    @State private var buttonOpacity: Double = 0
    @State private var animationTask: Task<Void, Never>?

    init(
        initialScene: MacVibesIntroScene,
        dictationModel: StyleRewriteDictationModel,
        localRewriteModelManager: MacLocalRewriteModelManager,
        onPreferredSizeChange: @escaping (CGSize) -> Void,
        onDismiss: @escaping () -> Void,
        onTryIt: @escaping () -> Void
    ) {
        self.initialScene = initialScene
        self.dictationModel = dictationModel
        self.localRewriteModelManager = localRewriteModelManager
        self.onPreferredSizeChange = onPreferredSizeChange
        self.onDismiss = onDismiss
        self.onTryIt = onTryIt
        _selectedScene = State(initialValue: initialScene)
    }

    var body: some View {
        VStack(spacing: 0) {
            topBar

            sceneView
                .id(selectedScene)
                .opacity(contentOpacity)
                .padding(.horizontal, 28)
                .padding(.vertical, 20)
                .fixedSize(horizontal: false, vertical: true)

            bottomActions
                .opacity(buttonOpacity)
        }
        .frame(width: selectedScene.preferredWindowSize.width)
        .fixedSize(horizontal: false, vertical: true)
        .background(MacAppTheme.screenBackground)
        .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
        .background(
            GeometryReader { geometry in
                Color.clear.preference(
                    key: ContentSizePreferenceKey.self,
                    value: geometry.size
                )
            }
        )
        .preferredColorScheme(.dark)
        .onAppear {
            selectedScene = initialScene
            startEntrance()
        }
        .onDisappear {
            animationTask?.cancel()
            animationTask = nil
        }
        .onPreferenceChange(ContentSizePreferenceKey.self) { size in
            guard size.width > 0, size.height > 0 else { return }
            onPreferredSizeChange(size)
        }
    }

    private var topBar: some View {
        HStack {
            Spacer()

            if isStandaloneSceneB == false {
                Button(action: onDismiss) {
                    Image(systemName: "xmark")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.58))
                        .frame(width: 36, height: 36)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Close")
                .padding(.trailing, 5)
            }
        }
        .frame(height: isStandaloneSceneB ? 0 : 46)
        .padding(.top, isStandaloneSceneB ? 0 : 5)
    }

    @ViewBuilder
    private var sceneView: some View {
        switch selectedScene {
        case .a:
            MacVibesIntroSceneAView(
                isVisible: selectedScene == .a,
                dictationModel: dictationModel
            )
        case .b:
            MacVibesIntroSceneBView(isVisible: selectedScene == .b)
        case .c:
            MacVibesIntroSceneCView(
                isVisible: selectedScene == .c,
                installState: localRewriteModelManager.installState,
                downloadAction: localRewriteModelManager.downloadModel
            )
        }
    }

    private var bottomActions: some View {
        HStack {
            Spacer()

            AppActionButton(
                title: actionTitle,
                style: .primary,
                minWidth: 108,
                isEnabled: isActionEnabled,
                action: handleAction
            )

            Spacer()
        }
        .padding(.horizontal, 24)
        .padding(.bottom, 20)
    }

    private var actionTitle: String {
        if isStandaloneSceneB {
            return "Done"
        }

        return selectedScene == .c ? "Try it" : "Next"
    }

    private var isStandaloneSceneB: Bool {
        initialScene == .b && selectedScene == .b
    }

    private var isActionEnabled: Bool {
        guard selectedScene == .c else { return true }

        switch localRewriteModelManager.installState {
        case .ready:
            return true
        case .notInstalled, .downloading, .installing, .failed:
            return false
        }
    }

    private func handleAction() {
        guard isActionEnabled else { return }

        if isStandaloneSceneB {
            onDismiss()
            return
        }

        if let nextScene = selectedScene.next {
            withAnimation(.easeInOut(duration: 0.22)) {
                selectedScene = nextScene
            }
            return
        }

        onTryIt()
    }

    private func startEntrance() {
        contentOpacity = 0
        buttonOpacity = 0
        animationTask?.cancel()

        animationTask = Task { @MainActor in
            try? await Task.sleep(for: .seconds(0.2))
            guard Task.isCancelled == false else { return }

            withAnimation(.easeIn(duration: 0.4)) {
                contentOpacity = 1
            }

            try? await Task.sleep(for: .seconds(0.5))
            guard Task.isCancelled == false else { return }

            withAnimation(.easeIn(duration: 0.4)) {
                buttonOpacity = 1
            }
        }
    }
}
