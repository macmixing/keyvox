import Combine
import CoreFoundation
import Foundation

@MainActor
final class AppLaunchRouteStore: ObservableObject {
    static let shared = AppLaunchRouteStore()

    @Published private(set) var initialURLRoute: KeyVoxURLRoute?
    @Published private(set) var hasResolvedInitialLaunchContext = false
    @Published private(set) var routeEventSequence: UInt64 = 0
    private var pendingURLRoute: KeyVoxURLRoute?

    init() {
        registerPendingRouteObserver()
    }

    deinit {
        let center = CFNotificationCenterGetDarwinNotifyCenter()
        CFNotificationCenterRemoveEveryObserver(center, Unmanaged.passUnretained(self).toOpaque())
    }

    func resolveInitialLaunchURL(_ url: URL?) {
        let route = url.flatMap(KeyVoxURLRoute.init(url:))
        stage(route: route)
    }

    func consumeInitialURLRoute() -> KeyVoxURLRoute? {
        let route = pendingURLRoute
        pendingURLRoute = nil
        return route
    }

    func consumePendingShortcutRoute() -> KeyVoxURLRoute? {
        KeyVoxIPCBridge.consumePendingURLRoute().flatMap(KeyVoxURLRoute.init(url:))
    }

    func consumePendingShortcutRouteIfNeeded() {
        let route = consumePendingShortcutRoute()
        guard let route else { return }
        stage(route: route)
    }

    func clearInitialPresentationRoute() {
        Task { @MainActor [weak self] in
            self?.initialURLRoute = nil
        }
    }

    private func stage(route: KeyVoxURLRoute?) {
        pendingURLRoute = route
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            self.initialURLRoute = route
            self.hasResolvedInitialLaunchContext = true
            if route != nil {
                self.routeEventSequence &+= 1
            }
        }
    }

    private func registerPendingRouteObserver() {
        let center = CFNotificationCenterGetDarwinNotifyCenter()
        CFNotificationCenterAddObserver(
            center,
            Unmanaged.passUnretained(self).toOpaque(),
            Self.notificationCallback,
            KeyVoxIPCBridge.Notification.pendingURLRouteReady as CFString,
            nil,
            .deliverImmediately
        )
    }

    private func handlePendingRouteNotification() {
        consumePendingShortcutRouteIfNeeded()
    }

    nonisolated private static let notificationCallback: CFNotificationCallback = { _, observer, _, _, _ in
        guard let observer else { return }
        let store = Unmanaged<AppLaunchRouteStore>.fromOpaque(observer).takeUnretainedValue()
        Task { @MainActor in
            store.handlePendingRouteNotification()
        }
    }
}
