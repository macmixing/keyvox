import Combine
import Foundation

@MainActor
final class AppLaunchRouteStore: ObservableObject {
    static let shared = AppLaunchRouteStore()

    @Published private(set) var initialURLRoute: KeyVoxURLRoute?
    @Published private(set) var hasResolvedInitialLaunchContext = false
    private var pendingURLRoute: KeyVoxURLRoute?

    func resolveInitialLaunchURL(_ url: URL?) {
        let route = url.flatMap(KeyVoxURLRoute.init(url:))

        Task { @MainActor [weak self] in
            guard let self else { return }
            pendingURLRoute = route
            initialURLRoute = route
            hasResolvedInitialLaunchContext = true
        }
    }

    func consumeInitialURLRoute() -> KeyVoxURLRoute? {
        let route = pendingURLRoute
        pendingURLRoute = nil
        return route
    }

    func clearInitialPresentationRoute() {
        Task { @MainActor [weak self] in
            self?.initialURLRoute = nil
        }
    }
}
