import SwiftUI

struct OnboardingKeyboardTourScreen: View {
    @Environment(\.scenePhase) private var scenePhase
    @EnvironmentObject private var onboardingStore: iOSOnboardingStore
    @State private var text = ""
    @State private var hasFreshKeyboardAccessConfirmation = false
    @StateObject private var keyboardObserver = KeyboardObserver()
    @StateObject private var keyboardAccessProbe: iOSOnboardingKeyboardAccessProbe

    @MainActor
    init(keyboardAccessProbe: iOSOnboardingKeyboardAccessProbe? = nil) {
        let resolvedKeyboardAccessProbe = keyboardAccessProbe ?? iOSOnboardingKeyboardAccessProbe()
        _keyboardAccessProbe = StateObject(wrappedValue: resolvedKeyboardAccessProbe)
    }

    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .bottom) {
                iOSAppTheme.screenBackground
                    .ignoresSafeArea()

                inputBar
                    .padding(.horizontal, iOSAppTheme.screenPadding)
                    .padding(.bottom, bottomPadding(for: geometry))
            }
            .safeAreaInset(edge: .top) {
                HStack {
                    Spacer()

                    Button("Finish") {
                        onboardingStore.completeKeyboardTour()
                    }
                    .tint(iOSAppTheme.accent)
                    .disabled(!hasFreshKeyboardAccessConfirmation)
                }
                .padding(.horizontal, iOSAppTheme.screenPadding)
                .padding(.top, 8)
                .padding(.bottom, 12)
                .background(iOSAppTheme.screenBackground.opacity(0.98))
            }
        }
        .task {
            hasFreshKeyboardAccessConfirmation = false
            keyboardAccessProbe.refresh()
        }
        .onChange(of: scenePhase, initial: false) { _, newPhase in
            guard newPhase == .active else { return }
            hasFreshKeyboardAccessConfirmation = false
            keyboardAccessProbe.refresh()
        }
        .onChange(of: keyboardObserver.keyboardHeight, initial: false) { _, newHeight in
            guard newHeight > 0 else { return }
            refreshAfterKeyboardPresentation()
        }
    }

    private var inputBar: some View {
        iOSAppCard {
            AutoFocusTextField(
                text: $text,
                placeholder: "",
                onSubmit: {}
            )
            .frame(height: 44)
        }
    }

    private func bottomPadding(for geometry: GeometryProxy) -> CGFloat {
        let keyboardInset = max(0, keyboardObserver.keyboardHeight - geometry.safeAreaInsets.bottom)
        return max(16, keyboardInset)
    }

    private func refreshAfterKeyboardPresentation() {
        keyboardAccessProbe.refresh()
        hasFreshKeyboardAccessConfirmation = keyboardAccessProbe.hasConfirmedKeyboardAccess

        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(250))
            keyboardAccessProbe.refresh()
            hasFreshKeyboardAccessConfirmation = keyboardAccessProbe.hasConfirmedKeyboardAccess
        }
    }
}
