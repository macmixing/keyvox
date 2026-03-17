import Combine
import Foundation
import Network

@MainActor
final class OnboardingDownloadNetworkMonitor: ObservableObject {
    @Published private(set) var isOnline: Bool
    @Published private(set) var isOnCellular: Bool

    private var cancelMonitoring: () -> Void

    convenience init(
        pathMonitor: NWPathMonitor = NWPathMonitor(),
        queue: DispatchQueue = DispatchQueue(label: "com.cueit.keyvox.ios.onboarding-network-monitor")
    ) {
        self.init { update in
            pathMonitor.pathUpdateHandler = { path in
                Task { @MainActor in
                    update(path.status == .satisfied, path.usesInterfaceType(.cellular))
                }
            }

            pathMonitor.start(queue: queue)
            return {
                pathMonitor.cancel()
            }
        }
    }

    init(
        initialIsOnline: Bool = true,
        initialIsOnCellular: Bool = false,
        startMonitoring: (@escaping (Bool, Bool) -> Void) -> (() -> Void)
    ) {
        isOnline = initialIsOnline
        isOnCellular = initialIsOnCellular
        cancelMonitoring = {}
        cancelMonitoring = startMonitoring { [weak self] isOnline, isOnCellular in
            self?.isOnline = isOnline
            self?.isOnCellular = isOnCellular
        }
    }

    deinit {
        cancelMonitoring()
    }
}
