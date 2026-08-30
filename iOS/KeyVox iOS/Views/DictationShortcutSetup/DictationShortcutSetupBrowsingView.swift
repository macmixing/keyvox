import SwiftUI

struct DictationShortcutSetupBrowsingView: View {
    enum Mode {
        case existingUserIntroduction
        case settingsReference
    }

    @Environment(\.appHaptics) private var appHaptics
    @State private var selectedPage = DictationShortcutSetupPage.one
    @State private var hasRequestedShortcutInstallation = false
    @State private var hasRequestedSettings = false
    @State private var errorMessage: String?

    let mode: Mode
    let onClose: () -> Void

    var body: some View {
        NavigationStack {
            ZStack {
                AppTheme.screenBackground
                    .ignoresSafeArea()

                VStack(spacing: 0) {
                    GeometryReader { pagerGeometry in
                        pager(in: pagerGeometry)
                    }

                    AppPageIndicator(
                        pageCount: DictationShortcutSetupPage.allCases.count,
                        selectedIndex: selectedPage.rawValue - 1,
                        onNavigate: handlePageIndicatorNavigation
                    )
                    .padding(.top, 12)
                    .padding(.bottom, 12)
                    .frame(maxWidth: .infinity)
                    .background(AppTheme.screenBackground)
                }
            }
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text("")
                        .font(.appFont(22))
                }

                if showsCloseButton {
                    if #available(iOS 26.0, *) {
                        ToolbarItem(placement: .topBarTrailing) {
                            closeButton
                        }
                        .sharedBackgroundVisibility(.hidden)
                    } else {
                        ToolbarItem(placement: .topBarTrailing) {
                            closeButton
                        }
                    }
                }
            }
            .toolbarBackground(.hidden, for: .navigationBar)
        }
        .interactiveDismissDisabled()
        .onAppear {
            selectedPage = .one
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

    private var closeButton: some View {
        Button(action: close) {
            Image(systemName: "xmark")
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(.white.opacity(0.58))
                .frame(width: 44, height: 44)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Close")
    }

    private var selectedPageScrollPosition: Binding<DictationShortcutSetupPage?> {
        Binding(
            get: { selectedPage },
            set: { page in
                if let page {
                    selectedPage = page
                }
            }
        )
    }

    @ViewBuilder
    private func pager(in geometry: GeometryProxy) -> some View {
        if #available(iOS 26.0, *) {
            pagerScrollView(in: geometry)
                .scrollEdgeEffectHidden()
        } else {
            pagerScrollView(in: geometry)
        }
    }

    private func pagerScrollView(in geometry: GeometryProxy) -> some View {
        ScrollView(.horizontal) {
            LazyHStack(spacing: 0) {
                ForEach(DictationShortcutSetupPage.allCases, id: \.self) { page in
                    VStack(spacing: 0) {
                        DictationShortcutSetupPageView(
                            page: page,
                            isActive: selectedPage == page
                        )

                        actionBar(for: page)
                    }
                    .frame(
                        width: geometry.size.width,
                        height: geometry.size.height
                    )
                    .id(page)
                }
            }
            .scrollTargetLayout()
        }
        .scrollIndicators(.hidden)
        .scrollTargetBehavior(.paging)
        .scrollPosition(id: selectedPageScrollPosition)
        .scrollClipDisabled()
    }

    private func actionBar(for page: DictationShortcutSetupPage) -> some View {
        actionSlot(for: page)
            .padding(.horizontal, 20)
            .padding(.top, 8)
    }

    private var showsCloseButton: Bool {
        switch mode {
        case .existingUserIntroduction:
            selectedPage != .seven
        case .settingsReference:
            true
        }
    }

    @ViewBuilder
    private func actionSlot(for page: DictationShortcutSetupPage) -> some View {
        switch mode {
        case .existingUserIntroduction:
            AppActionButton(
                title: guidedActionTitle(for: page),
                style: .primary,
                fillsWidth: true,
                size: .compact,
                fontSize: 22,
                action: { handleGuidedAction(for: page) }
            )
        case .settingsReference:
            switch page {
            case .two:
                AppActionButton(
                    title: "Add Shortcut",
                    style: .primary,
                    fillsWidth: true,
                    size: .compact,
                    fontSize: 22,
                    action: addShortcut
                )
            case .six:
                AppActionButton(
                    title: "Open Settings",
                    style: .primary,
                    fillsWidth: true,
                    size: .compact,
                    fontSize: 22,
                    action: openSettings
                )
            case .one, .three, .four, .five, .seven:
                Color.clear
                    .frame(height: 36)
                    .accessibilityHidden(true)
            }
        }
    }

    private func guidedActionTitle(for page: DictationShortcutSetupPage) -> String {
        switch page {
        case .one, .three:
            "Continue"
        case .two:
            hasRequestedShortcutInstallation ? "Next" : "Add Shortcut"
        case .four, .five:
            "Next"
        case .six:
            hasRequestedSettings ? "Next" : "Open Settings"
        case .seven:
            "Finish"
        }
    }

    private func handleGuidedAction(for page: DictationShortcutSetupPage) {
        switch page {
        case .one, .three, .four, .five:
            advance(from: page)
        case .two:
            if hasRequestedShortcutInstallation {
                advance(from: page)
            } else {
                hasRequestedShortcutInstallation = true
                addShortcut()
            }
        case .six:
            if hasRequestedSettings {
                advance(from: page)
            } else {
                hasRequestedSettings = true
                openSettings()
            }
        case .seven:
            appHaptics.medium()
            onClose()
        }
    }

    private func advance(from page: DictationShortcutSetupPage) {
        guard let nextPage = page.next else { return }
        appHaptics.light()
        withAnimation(.easeInOut(duration: 0.32)) {
            selectedPage = nextPage
        }
    }

    private func close() {
        appHaptics.light()
        onClose()
    }

    private func handlePageIndicatorNavigation(_ direction: AppPageIndicator.NavigationDirection) {
        let destinationPage = switch direction {
        case .previous:
            selectedPage.previous
        case .next:
            selectedPage.next
        }
        guard let destinationPage else { return }

        appHaptics.light()
        withAnimation(.easeInOut(duration: 0.32)) {
            selectedPage = destinationPage
        }
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
