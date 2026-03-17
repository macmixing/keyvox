import Combine
import Foundation
import Network

@MainActor
final class OnboardingDownloadNetworkMonitor: ObservableObject {
    @Published private(set) var isOnCellular: Bool

    private let pathMonitor: NWPathMonitor
    private let queue: DispatchQueue

    init(
        pathMonitor: NWPathMonitor = NWPathMonitor(),
        queue: DispatchQueue = DispatchQueue(label: "com.cueit.keyvox.ios.onboarding-network-monitor")
    ) {
        self.pathMonitor = pathMonitor
        self.queue = queue
        isOnCellular = false

        pathMonitor.pathUpdateHandler = { [weak self] path in
            Task { @MainActor [weak self] in
                self?.isOnCellular = path.usesInterfaceType(.cellular)
            }
        }
        pathMonitor.start(queue: queue)
    }

    deinit {
        pathMonitor.cancel()
    }
}
