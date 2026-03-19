import Testing
@testable import KeyVox_iOS

@MainActor
struct OnboardingDownloadNetworkMonitorTests {
    @Test func startsOnlineAndNonCellularBeforeFirstNetworkUpdate() {
        let monitor = OnboardingDownloadNetworkMonitor(startMonitoring: { _ in {} })

        #expect(monitor.isOnline)
        #expect(monitor.isOnCellular == false)
    }

    @Test func updatesPublishedNetworkStateFromMonitorCallback() {
        var updateNetworkState: ((Bool, Bool) -> Void)?
        let monitor = OnboardingDownloadNetworkMonitor(startMonitoring: { update in
            updateNetworkState = update
            return {}
        })

        updateNetworkState?(false, false)
        #expect(monitor.isOnline == false)
        #expect(monitor.isOnCellular == false)

        updateNetworkState?(true, true)
        #expect(monitor.isOnline)
        #expect(monitor.isOnCellular)
    }

    @Test func cancelsUnderlyingMonitoringWhenReleased() {
        var cancelCount = 0
        var monitor: OnboardingDownloadNetworkMonitor? = OnboardingDownloadNetworkMonitor(startMonitoring: { _ in
            return {
                cancelCount += 1
            }
        })

        #expect(monitor != nil)
        #expect(cancelCount == 0)
        monitor = nil
        #expect(cancelCount == 1)
    }
}
