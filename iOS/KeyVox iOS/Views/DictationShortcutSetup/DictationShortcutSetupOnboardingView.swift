import Foundation
import SwiftUI

struct DictationShortcutSetupOnboardingView: View {
    private enum PageDirection: Equatable {
        case forward
        case backward
    }

    @Environment(\.appHaptics) private var appHaptics
    @State private var selectedPage: DictationShortcutSetupPage
    @State private var pageDirection = PageDirection.forward
    @Binding private var hasRequestedShortcutInstallation: Bool
    @Binding private var hasRequestedSettings: Bool
    @State private var errorMessage: String?
    /// Whether setup opened on its last page, which happens when someone returns from keyboard
    /// setup after finishing these steps on an earlier launch.
    @State private var opensAfterCompletedSetup: Bool

    let onReturnToSetup: () -> Void
    let onContinueToKeyboardSetup: () -> Void

    init(
        initialPage: DictationShortcutSetupPage = .shortcutIntro,
        hasRequestedShortcutInstallation: Binding<Bool>,
        hasRequestedSettings: Binding<Bool>,
        onReturnToSetup: @escaping () -> Void,
        onContinueToKeyboardSetup: @escaping () -> Void
    ) {
        _selectedPage = State(initialValue: initialPage)
        _opensAfterCompletedSetup = State(initialValue: initialPage == DictationShortcutSetupPage.finalPage)
        _hasRequestedShortcutInstallation = hasRequestedShortcutInstallation
        _hasRequestedSettings = hasRequestedSettings
        self.onReturnToSetup = onReturnToSetup
        self.onContinueToKeyboardSetup = onContinueToKeyboardSetup
    }

    var body: some View {
        NavigationStack {
            ZStack {
                AppTheme.screenBackground
                    .ignoresSafeArea()

                VStack(spacing: 0) {
                    GeometryReader { geometry in
                        ZStack {
                            ScrollView(showsIndicators: false) {
                                Color.clear
                                    .frame(maxWidth: .infinity)
                                    .frame(minHeight: geometry.size.height)
                            }
                            .scrollDisabled(true)

                            pageContent
                        }
                    }

                    bottomBar
                }
            }
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    if selectedPage == .shortcutIntro {
                        Button(action: returnToSetup) {
                            Label(String(localized: "Back", comment: "Toolbar button that goes back to the previous onboarding screen."), systemImage: "chevron.left")
                        }
                    } else {
                        Button(action: goBack) {
                            Label(String(localized: "Back", comment: "Toolbar button that goes back to the previous onboarding screen."), systemImage: "chevron.left")
                        }
                    }
                }

                ToolbarItem(placement: .principal) {
                    Text("")
                        .font(.appFont(22))
                }

                if finishesSetup == false {
                    if #available(iOS 26.0, *) {
                        ToolbarItem(placement: .topBarTrailing) {
                            skipButton
                        }
                        .sharedBackgroundVisibility(.hidden)
                    } else {
                        ToolbarItem(placement: .topBarTrailing) {
                            skipButton
                        }
                    }
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.hidden, for: .navigationBar)
            .containerBackground(AppTheme.screenBackground, for: .navigation)
        }
        .alert(
            String(localized: "Unable to Complete Action", comment: "Title of the alert shown when a dictation shortcut setup action fails."),
            isPresented: Binding(
                get: { errorMessage != nil },
                set: { isPresented in
                    if isPresented == false {
                        errorMessage = nil
                    }
                }
            )
        ) {
            Button(String(localized: "OK", comment: "Button that dismisses the dictation shortcut setup error alert."), role: .cancel) {
                errorMessage = nil
            }
        } message: {
            Text(errorMessage ?? "")
        }
    }

    private var pageContent: some View {
        DictationShortcutSetupPageView(
            page: selectedPage,
            isActive: true,
            animatesShortcutIntroEntrance: pageDirection == .forward
        )
            .id(selectedPage)
            .transition(pageTransition)
            .animation(.easeInOut(duration: 0.32), value: selectedPage)
    }

    private var pageTransition: AnyTransition {
        switch pageDirection {
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
        }
    }

    private var bottomBar: some View {
        VStack(spacing: 12) {
            AppActionButton(
                title: actionTitle,
                style: .primary,
                fillsWidth: true,
                size: .compact,
                fontSize: 22,
                action: handleAction
            )
            .accessibilitySortPriority(1)

            AppPageIndicator(
                pageCount: DictationShortcutSetupPage.available.count,
                selectedIndex: selectedPage.availableIndex
            )
        }
        .padding(.horizontal, 20)
        .appReadableWidth(horizontalPadding: 20)
        .padding(.top, 8)
        .padding(.bottom, 12)
    }

    private var skipButton: some View {
        AppActionButton(
            title: String(localized: "Skip", comment: "Button that skips the dictation shortcut setup during onboarding."),
            style: .secondary,
            minWidth: 72,
            size: .compact,
            fontSize: 16,
            action: complete
        )
        .fixedSize(horizontal: true, vertical: false)
    }

    /// Whether the button on the current page leaves for keyboard setup: it's the last page and
    /// its own step is done.
    private var finishesSetup: Bool {
        selectedPage.next == nil
            && (selectedPage != .addShortcut || hasRequestedShortcutInstallation || opensAfterCompletedSetup)
    }

    private var actionTitle: String {
        switch selectedPage {
        case .shortcutIntro, .actionButtonIntro:
            return String(localized: "Continue", comment: "Button that moves to the next page of the dictation shortcut setup.")
        case .addShortcut:
            if finishesSetup {
                return String(localized: "Set Up Keyboard", comment: "Button on the last page of the dictation shortcut setup during onboarding that moves on to keyboard setup.")
            }
            return hasRequestedShortcutInstallation ? String(localized: "Next", comment: "Button that moves to the next page of the dictation shortcut setup.") : String(localized: "Add Shortcut", comment: "Button in the dictation shortcut setup that adds the KeyVox shortcut to the Shortcuts app.")
        case .actionButtonSettings, .actionButtonShortcutOption:
            return String(localized: "Next", comment: "Button that moves to the next page of the dictation shortcut setup.")
        case .actionButtonShortcutSelection:
            return hasRequestedSettings ? String(localized: "Next", comment: "Button that moves to the next page of the dictation shortcut setup.") : String(localized: "Open Settings", comment: "Button in the dictation shortcut setup that opens the Settings app. Use Apple's official name for Settings in this language.")
        case .actionButtonDemoPaste:
            return String(localized: "Next", comment: "Button that moves to the next page of the dictation shortcut setup.")
        case .actionButtonDemoHandoff:
            return String(localized: "Set Up Keyboard", comment: "Button on the last page of the dictation shortcut setup during onboarding that moves on to keyboard setup.")
        }
    }

    private func handleAction() {
        switch selectedPage {
        case .shortcutIntro, .actionButtonIntro, .actionButtonSettings,
             .actionButtonShortcutOption, .actionButtonDemoPaste:
            advance()
        case .addShortcut:
            if finishesSetup {
                complete()
            } else if hasRequestedShortcutInstallation {
                advance()
            } else {
                hasRequestedShortcutInstallation = true
                addShortcut()
            }
        case .actionButtonShortcutSelection:
            if hasRequestedSettings {
                advance()
            } else {
                hasRequestedSettings = true
                openSettings()
            }
        case .actionButtonDemoHandoff:
            complete()
        }
    }

    private func advance() {
        guard let nextPage = selectedPage.next else { return }
        appHaptics.light()
        pageDirection = .forward
        withAnimation(.easeInOut(duration: 0.32)) {
            selectedPage = nextPage
        }
    }

    private func goBack() {
        guard let previousPage = selectedPage.previous else { return }
        appHaptics.light()
        pageDirection = .backward
        withAnimation(.easeInOut(duration: 0.32)) {
            selectedPage = previousPage
        }
    }

    private func returnToSetup() {
        appHaptics.light()
        onReturnToSetup()
    }

    private func complete() {
        appHaptics.medium()
        onContinueToKeyboardSetup()
    }

    private func addShortcut() {
        appHaptics.light()
        Task {
            do {
                try await DictationShortcutInstaller.openInstallation()
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }

    private func openSettings() {
        appHaptics.light()
        Task {
            guard await DictationShortcutSettingsOpener.open() else {
                errorMessage = String(localized: "The Settings app could not be opened.", comment: "Error message in the dictation shortcut setup when the Settings app could not be opened. Use Apple's official name for Settings in this language.")
                return
            }
        }
    }
}
