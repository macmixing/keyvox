import SwiftUI
import UIKit

struct OnboardingEnableKeyboardScreen: View {
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.appHaptics) private var appHaptics
    @EnvironmentObject private var onboardingStore: OnboardingStore
    @StateObject private var keyboardAccessProbe: OnboardingKeyboardAccessProbe
    @State private var isVideoReady = false

    @MainActor
    init(keyboardAccessProbe: OnboardingKeyboardAccessProbe? = nil) {
        _keyboardAccessProbe = StateObject(
            wrappedValue: keyboardAccessProbe ?? OnboardingKeyboardAccessProbe()
        )
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 20) {
                        Text("Enable Keyboard")
                            .font(.appFont(30))
                            .foregroundStyle(.white)

                        Text("Enable KeyVox’s keyboard and turn on Allow Full Access in Settings, then come back here.")
                            .font(.appFont(17, variant: .light))
                            .foregroundStyle(.white.opacity(0.72))

                        LoopingVideoPlayer(
                            videoName: "EnableKeyboard",
                            isReady: $isVideoReady
                        )
                        .aspectRatio(1024.0 / 700.0, contentMode: .fit)
                        .frame(maxWidth: 350)
                        .frame(maxWidth: .infinity)
                        .accessibilityHidden(true)
                    }
                    .frame(maxWidth: .infinity, alignment: .topLeading)
                    .padding(.horizontal, AppTheme.screenPadding)
                    .padding(.top, AppTheme.screenPadding)
                    .padding(.bottom, 20)
                }

                AppActionButton(
                    title: "Open Settings",
                    style: .primary,
                    fillsWidth: true,
                    fontSize: 20,
                    action: openKeyboardSettings
                )
                .padding(.horizontal, AppTheme.screenPadding)
                .padding(.top, 8)
                .padding(.bottom, 12)
            }
            .background(AppTheme.screenBackground.ignoresSafeArea())
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button(action: returnToDictationShortcutSetup) {
                        Label("Back", systemImage: "chevron.left")
                    }
                }
            }
            .toolbarBackground(.hidden, for: .navigationBar)
        }
        .preferredColorScheme(.dark)
        .task {
            refreshKeyboardState()
        }
        .onChange(of: scenePhase, initial: false) { _, newPhase in
            guard newPhase == .active else { return }
            refreshKeyboardState()
        }
        .onChange(of: keyboardAccessProbe.isKeyboardEnabledInSystemSettings, initial: false) { _, _ in
            armKeyboardTourIfReady()
        }
    }

    private func openKeyboardSettings() {
        guard let bundleIdentifier = Bundle.main.bundleIdentifier,
              let url = URL(string: "App-prefs:\(bundleIdentifier)") else {
            return
        }

        appHaptics.light()
        KeyVoxIPCBridge.clearKeyboardOnboardingPresentation()
        UIApplication.shared.open(url)
    }

    private func returnToDictationShortcutSetup() {
        appHaptics.light()
        onboardingStore.beginDictationShortcutSetup()
    }

    private func refreshKeyboardState() {
        keyboardAccessProbe.refresh()
        armKeyboardTourIfReady()
    }

    private func armKeyboardTourIfReady() {
        onboardingStore.armPendingKeyboardTourRouteIfNeeded(
            isKeyboardEnabledInSystemSettings: keyboardAccessProbe.isKeyboardEnabledInSystemSettings
        )
    }
}
