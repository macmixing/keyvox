import Foundation
import KeyVoxStyleRewrite
import Testing
@testable import KeyVox_iOS

@MainActor
struct KeyVoxVibesPurchaseControllerTests {
    @Test func lockedUsersStartWithoutVibesAccess() async throws {
        let harness = makeHarness()
        defer { harness.cleanup() }

        let controller = makeController(harness: harness)
        await settleAsyncWork()

        #expect(controller.isVibesUnlocked == false)
        #expect(controller.hasTrialStarted == false)
        #expect(controller.canUseVibes == false)
    }

    @Test func startingTrialEnablesVibesForOneDay() async throws {
        let harness = makeHarness()
        defer { harness.cleanup() }

        let controller = makeController(harness: harness)
        await settleAsyncWork()

        controller.startTrial()

        #expect(controller.hasTrialStarted == true)
        #expect(controller.isTrialActive == true)
        #expect(controller.canUseVibes == true)
        #expect(harness.defaults.object(forKey: UserDefaultsKeys.App.vibesTrialStartedAt) as? Date == harness.now)
    }

    @Test func activeTrialFormatsRemainingTime() async throws {
        let harness = makeHarness()
        defer { harness.cleanup() }

        let controller = makeController(harness: harness)
        await settleAsyncWork()

        controller.startTrial()
        harness.now = harness.now.addingTimeInterval((2 * 60 * 60) + (15 * 60))

        #expect(controller.trialRemainingText == "21h 45m")
    }

    @Test func expiredTrialDisablesVibesAndResetsSelectedVibe() async throws {
        let harness = makeHarness()
        defer { harness.cleanup() }

        let controller = makeController(harness: harness)
        await settleAsyncWork()

        controller.startTrial()
        harness.selectedVibe = .chill
        harness.now = harness.now.addingTimeInterval(KeyVoxVibesPurchaseController.trialDuration + 1)
        controller.refreshTrialStateIfNeeded()

        #expect(controller.canUseVibes == false)
        #expect(controller.hasTrialEnded == true)
        #expect(harness.selectedVibe == .none)
    }

    @Test func purchaseUnlockEnablesVibesAndDismissesSheet() async throws {
        let harness = makeHarness()
        defer { harness.cleanup() }

        let controller = makeController(harness: harness)
        await settleAsyncWork()

        controller.presentUnlockSheet()
        await controller.purchaseVibesUnlock()

        #expect(controller.isVibesUnlocked == true)
        #expect(controller.canUseVibes == true)
        #expect(controller.sheetPresentation == nil)
    }

    @Test func restorePurchasesChecksVibesEntitlement() async throws {
        let harness = makeHarness()
        defer { harness.cleanup() }

        let controller = makeController(harness: harness)
        await settleAsyncWork()

        harness.store.restoreWillUnlock = true
        await controller.restorePurchases()

        #expect(controller.isVibesUnlocked == true)
        #expect(controller.canUseVibes == true)
    }

    private func makeController(harness: KeyVoxVibesPurchaseHarness) -> KeyVoxVibesPurchaseController {
        KeyVoxVibesPurchaseController(
            defaults: harness.defaults,
            store: harness.store,
            now: { harness.now },
            setSelectedVibe: { harness.selectedVibe = $0 }
        )
    }

    private func makeHarness() -> KeyVoxVibesPurchaseHarness {
        let suiteName = "KeyVoxVibesPurchaseControllerTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        let store = StubVibesUnlockStore(isUnlocked: false)
        return KeyVoxVibesPurchaseHarness(
            defaults: defaults,
            store: store,
            now: Date(timeIntervalSince1970: 0),
            suiteName: suiteName
        )
    }

    private func settleAsyncWork() async {
        for _ in 0..<5 {
            await Task.yield()
        }
    }
}

@MainActor
private final class KeyVoxVibesPurchaseHarness {
    let defaults: UserDefaults
    let store: StubVibesUnlockStore
    var now: Date
    var selectedVibe: StyleRewriteStyle = .none
    private let suiteName: String

    init(defaults: UserDefaults, store: StubVibesUnlockStore, now: Date, suiteName: String) {
        self.defaults = defaults
        self.store = store
        self.now = now
        self.suiteName = suiteName
    }

    func cleanup() {
        defaults.removePersistentDomain(forName: suiteName)
    }
}

private final class StubVibesUnlockStore: StoreUnlockStore {
    var isUnlocked: Bool
    var restoreWillUnlock: Bool

    init(isUnlocked: Bool) {
        self.isUnlocked = isUnlocked
        self.restoreWillUnlock = isUnlocked
    }

    func loadUnlockProduct(productID: String) async throws -> StoreUnlockProduct? {
        StoreUnlockProduct(id: productID, displayName: "KeyVox Vibes Lifetime Unlock", displayPrice: "$4.99")
    }

    func isUnlocked(productID: String) async throws -> Bool {
        isUnlocked
    }

    func purchase(productID: String) async throws -> Bool {
        isUnlocked = true
        return true
    }

    func restore(productID: String) async throws -> Bool {
        isUnlocked = restoreWillUnlock
        return isUnlocked
    }
}
