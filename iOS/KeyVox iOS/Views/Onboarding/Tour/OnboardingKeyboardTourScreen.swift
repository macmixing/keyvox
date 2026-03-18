import Combine
import SwiftUI
import UIKit

struct OnboardingKeyboardTourScreen: View {
    private enum Metrics {
        static let inputBarHeight: CGFloat = 44
        static let inputBarBottomSpacing: CGFloat = 16
        static let sceneBottomSpacing: CGFloat = 92
    }

    private enum TourSceneDirection {
        case forward
        case backward
        case none
    }

    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.appHaptics) private var appHaptics
    @EnvironmentObject private var onboardingStore: OnboardingStore
    @EnvironmentObject private var transcriptionManager: TranscriptionManager
    @State private var text = ""
    @State private var tourState = OnboardingKeyboardTourState()
    @State private var previousScene = OnboardingKeyboardTourState.Scene.a
    @State private var isInputBarVisible = true
    @StateObject private var keyboardObserver = KeyboardObserver()
    @StateObject private var keyboardAccessProbe: OnboardingKeyboardAccessProbe

    @MainActor
    init(keyboardAccessProbe: OnboardingKeyboardAccessProbe? = nil) {
        let resolvedKeyboardAccessProbe = keyboardAccessProbe ?? OnboardingKeyboardAccessProbe()
        _keyboardAccessProbe = StateObject(wrappedValue: resolvedKeyboardAccessProbe)
    }

    var body: some View {
        GeometryReader { geometry in
            AppTheme.screenBackground
                .ignoresSafeArea()
                .overlay {
                    // Keep scene content on its own overlay layer so it cannot
                    // participate in the input bar's layout when scene copy grows.
                    sceneContent
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
                        .padding(.horizontal, AppTheme.screenPadding)
                        .padding(.bottom, sceneBottomPadding(for: geometry))
                }
                .overlay(alignment: .bottom) {
                    if isInputBarVisible {
                        inputBar
                            .padding(.horizontal, AppTheme.screenPadding)
                            .padding(.bottom, Metrics.inputBarBottomSpacing)
                            .offset(y: -keyboardLift(for: geometry))
                            .transition(.opacity)
                    }
                }
        }
        .safeAreaInset(edge: .top) {
            ZStack {
                if let topBarTitle {
                    Text(topBarTitle)
                        .font(.appFont(22))
                        .foregroundStyle(.white)
                        .id(topBarTitle)
                        .transition(.opacity.combined(with: .offset(y: -8)))
                }

                HStack {
                    Spacer()

                    AppActionButton(
                        title: primaryActionTitle,
                        style: .primary,
                        size: .compact,
                        fontSize: 16,
                        isEnabled: tourState.canFinish,
                        action: handlePrimaryAction
                    )
                }
                .frame(maxWidth: .infinity)
            }
            .frame(maxWidth: .infinity)
            .padding(.horizontal, AppTheme.screenPadding)
            .padding(.top, 8)
            .padding(.bottom, 12)
            .background(AppTheme.screenBackground.opacity(0.98))
        }
        .ignoresSafeArea(.keyboard)
        .task {
            tourState = OnboardingKeyboardTourState()
            previousScene = tourState.scene
            isInputBarVisible = true
            keyboardAccessProbe.refresh()
            syncKeyboardPresentationState()
        }
        .onChange(of: scenePhase, initial: false) { _, newPhase in
            guard newPhase == .active else { return }
            keyboardAccessProbe.refresh()
            syncKeyboardPresentationState()
        }
        .onChange(of: keyboardObserver.keyboardHeight, initial: false) { _, newHeight in
            guard newHeight > 0 else { return }
            refreshAfterKeyboardPresentation()
        }
        .onReceive(transcriptionManager.$lastTranscriptionText.dropFirst()) { latestTranscription in
            handleLatestTranscription(latestTranscription)
        }
        .onChange(of: tourState.scene, initial: false) { oldScene, newScene in
            guard oldScene != newScene else { return }
            previousScene = oldScene
        }
    }

    private var topBarTitle: String? {
        switch tourState.scene {
        case .a:
            return "Select KeyVox"
        case .b:
            return "Try It Out!"
        case .c:
            return "Success!"
        }
    }

    private var primaryActionTitle: String {
        tourState.scene == .c ? "Finish" : "Next"
    }

    private var sceneContent: some View {
        Group {
            switch tourState.scene {
            case .a:
                OnboardingKeyboardTourSceneAView()
            case .b:
                OnboardingKeyboardTourSceneBView()
            case .c:
                OnboardingKeyboardTourSceneCView()
            }
        }
        .id(tourState.scene)
        .transition(sceneTransition)
        .animation(.easeInOut(duration: 0.32), value: tourState.scene)
    }

    private var sceneTransition: AnyTransition {
        switch sceneDirection {
        case .forward:
            return .asymmetric(
                insertion: .move(edge: .trailing).combined(with: .opacity),
                removal: .move(edge: .leading).combined(with: .opacity)
            )
        case .backward:
            return .asymmetric(
                insertion: .move(edge: .leading).combined(with: .opacity),
                removal: .move(edge: .trailing).combined(with: .opacity)
            )
        case .none:
            return .opacity
        }
    }

    private var sceneDirection: TourSceneDirection {
        switch (previousScene, tourState.scene) {
        case let (oldScene, newScene) where oldScene == newScene:
            return .none
        case (.a, .b), (.b, .c), (.a, .c):
            return .forward
        case (.c, .b), (.b, .a), (.c, .a):
            return .backward
        default:
            return .none
        }
    }

    private var inputBar: some View {
        AppCard {
            AutoFocusTextField(
                text: $text,
                placeholder: "",
                onSubmit: {}
            )
            .frame(height: 44)
        }
    }

    private func keyboardLift(for geometry: GeometryProxy) -> CGFloat {
        guard keyboardObserver.keyboardHeight > 0 else {
            return 0
        }

        return max(0, keyboardObserver.keyboardHeight - geometry.safeAreaInsets.bottom)
    }

    private func sceneBottomPadding(for geometry: GeometryProxy) -> CGFloat {
        keyboardLift(for: geometry)
            + Metrics.inputBarHeight
            + Metrics.inputBarBottomSpacing
            + Metrics.sceneBottomSpacing
    }

    private func refreshAfterKeyboardPresentation() {
        keyboardAccessProbe.refresh()
        syncKeyboardPresentationState()

        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(250))
            keyboardAccessProbe.refresh()
            syncKeyboardPresentationState()
        }
    }

    private func syncKeyboardPresentationState() {
        guard keyboardAccessProbe.hasShownKeyVoxKeyboard else { return }
        tourState.hasShownKeyVoxKeyboard = true
    }

    private func handleLatestTranscription(_ latestTranscription: String?) {
        guard scenePhase == .active,
              tourState.hasShownKeyVoxKeyboard,
              let latestTranscription,
              !latestTranscription.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return
        }

        tourState.hasCompletedFirstTourTranscription = true
    }

    private func handlePrimaryAction() {
        guard tourState.canFinish else { return }

        if tourState.scene == .c {
            appHaptics.medium()
            withAnimation(.easeOut(duration: 0.18)) {
                isInputBarVisible = false
            }

            UIApplication.shared.sendAction(
                #selector(UIResponder.resignFirstResponder),
                to: nil,
                from: nil,
                for: nil
            )

            Task { @MainActor in
                try? await Task.sleep(for: .milliseconds(500))
                onboardingStore.completeKeyboardTour()
            }
            return
        }

        onboardingStore.completeKeyboardTour()
    }
}
