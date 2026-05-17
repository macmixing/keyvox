import AppKit
import Combine

@MainActor
final class DockIconVisibilityController {
    static let shared = DockIconVisibilityController()

    private let appSettings: AppSettingsStore
    private let windowManager: WindowManager
    private let osVersion: OperatingSystemVersion
    private var cancellables = Set<AnyCancellable>()
    private var isStarted = false
    private var currentPolicy: NSApplication.ActivationPolicy?

    init(
        appSettings: AppSettingsStore? = nil,
        windowManager: WindowManager? = nil,
        osVersion: OperatingSystemVersion = ProcessInfo.processInfo.operatingSystemVersion
    ) {
        self.appSettings = appSettings ?? AppSettingsStore.shared
        self.windowManager = windowManager ?? WindowManager.shared
        self.osVersion = osVersion
    }

    func start() {
        guard !isStarted else { return }
        isStarted = true

        appSettings.$hideDockIconWhenAllWindowsClosed
            .sink { [weak self] _ in
                self?.syncActivationPolicy()
            }
            .store(in: &cancellables)

        observeWindowVisibilityChanges()
        syncActivationPolicy()
    }

    func syncActivationPolicy() {
        let policy = resolvedActivationPolicy(
            hidesDockIconPreference: appSettings.hideDockIconWhenAllWindowsClosed,
            hasVisibleManagedWindow: hasVisibleManagedWindow
        )

        guard currentPolicy != policy else { return }
        NSApplication.shared.setActivationPolicy(policy)
        currentPolicy = policy
    }

    func resolvedActivationPolicy(
        hidesDockIconPreference: Bool,
        hasVisibleManagedWindow: Bool
    ) -> NSApplication.ActivationPolicy {
        if KeyVoxApp.shouldUseAccessoryActivationPolicy(osVersion: osVersion) {
            return .accessory
        }

        if hidesDockIconPreference && !hasVisibleManagedWindow {
            return .accessory
        }

        return .regular
    }

    private var hasVisibleManagedWindow: Bool {
        [
            windowManager.settingsWindow,
            windowManager.onboardingWindow,
            windowManager.updateWindow,
            windowManager.postUpdateNoticeWindow,
            windowManager.vibesIntroWindow
        ]
        .compactMap { $0 }
        .contains { $0.isVisible }
    }

    private func observeWindowVisibilityChanges() {
        let notificationNames: [Notification.Name] = [
            NSWindow.didBecomeKeyNotification,
            NSWindow.didResignKeyNotification,
            NSWindow.didMiniaturizeNotification,
            NSWindow.didDeminiaturizeNotification,
            NSWindow.didChangeOcclusionStateNotification,
            NSWindow.willCloseNotification
        ]

        for name in notificationNames {
            NotificationCenter.default.publisher(for: name)
                .sink { [weak self] _ in
                    Task { @MainActor in
                        self?.syncActivationPolicy()
                    }
                }
                .store(in: &cancellables)
        }
    }
}
