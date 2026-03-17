import Combine
import SwiftUI

struct OnboardingKeyboardTourScreen: View {
    private enum Metrics {
        static let inputBarHeight: CGFloat = 44
        static let inputBarBottomSpacing: CGFloat = 16
        static let sceneBottomSpacing: CGFloat = 92
    }

    @Environment(\.scenePhase) private var scenePhase
    @EnvironmentObject private var onboardingStore: OnboardingStore
    @EnvironmentObject private var transcriptionManager: TranscriptionManager
    @State private var text = ""
    @State private var tourState = OnboardingKeyboardTourState()
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
                    inputBar
                        .padding(.horizontal, AppTheme.screenPadding)
                        .padding(.bottom, Metrics.inputBarBottomSpacing)
                        .offset(y: -keyboardLift(for: geometry))
                }
        }
        .safeAreaInset(edge: .top) {
            HStack {
                Spacer()

                AppActionButton(
                    title: "Next",
                    style: .primary,
                    size: .compact,
                    fontSize: 16,
                    isEnabled: tourState.canFinish,
                    action: onboardingStore.completeKeyboardTour
                )
            }
            .padding(.horizontal, AppTheme.screenPadding)
            .padding(.top, 8)
            .padding(.bottom, 12)
            .background(AppTheme.screenBackground.opacity(0.98))
        }
        .ignoresSafeArea(.keyboard)
        .task {
            tourState = OnboardingKeyboardTourState()
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
}
