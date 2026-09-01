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

    let onReturnToSetup: () -> Void
    let onContinueToKeyboardSetup: () -> Void

    init(
        initialPage: DictationShortcutSetupPage = .one,
        hasRequestedShortcutInstallation: Binding<Bool>,
        hasRequestedSettings: Binding<Bool>,
        onReturnToSetup: @escaping () -> Void,
        onContinueToKeyboardSetup: @escaping () -> Void
    ) {
        _selectedPage = State(initialValue: initialPage)
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
                    if selectedPage == .one {
                        Button(action: returnToSetup) {
                            Label("Back", systemImage: "chevron.left")
                        }
                    } else {
                        Button(action: goBack) {
                            Label("Back", systemImage: "chevron.left")
                        }
                    }
                }

                ToolbarItem(placement: .principal) {
                    Text("")
                        .font(.appFont(22))
                }

                if selectedPage != .eight {
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
            .toolbarBackground(.hidden, for: .navigationBar)
            .containerBackground(AppTheme.screenBackground, for: .navigation)
        }
        .alert(
            "Unable to Complete Action",
            isPresented: Binding(
                get: { errorMessage != nil },
                set: { isPresented in
                    if isPresented == false {
                        errorMessage = nil
                    }
                }
            )
        ) {
            Button("OK", role: .cancel) {
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
            animatesPageOneEntrance: pageDirection == .forward
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

            AppPageIndicator(
                pageCount: DictationShortcutSetupPage.allCases.count,
                selectedIndex: selectedPage.rawValue - 1
            )
        }
        .padding(.horizontal, 20)
        .padding(.top, 8)
        .padding(.bottom, 12)
    }

    private var skipButton: some View {
        AppActionButton(
            title: "Skip",
            style: .secondary,
            minWidth: 72,
            size: .compact,
            fontSize: 16,
            action: complete
        )
        .fixedSize(horizontal: true, vertical: false)
    }

    private var actionTitle: String {
        switch selectedPage {
        case .one, .three:
            return "Continue"
        case .two:
            return hasRequestedShortcutInstallation ? "Next" : "Add Shortcut"
        case .four, .five:
            return "Next"
        case .six:
            return hasRequestedSettings ? "Next" : "Open Settings"
        case .seven:
            return "Next"
        case .eight:
            return "Set Up Keyboard"
        }
    }

    private func handleAction() {
        switch selectedPage {
        case .one, .three, .four, .five, .seven:
            advance()
        case .two:
            if hasRequestedShortcutInstallation {
                advance()
            } else {
                hasRequestedShortcutInstallation = true
                addShortcut()
            }
        case .six:
            if hasRequestedSettings {
                advance()
            } else {
                hasRequestedSettings = true
                openSettings()
            }
        case .eight:
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
                errorMessage = "The Settings app could not be opened."
                return
            }
        }
    }
}
