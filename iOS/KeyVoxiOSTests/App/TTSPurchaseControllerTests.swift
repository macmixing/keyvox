import Foundation
import Testing
@testable import KeyVox_iOS

@MainActor
struct TTSPurchaseControllerTests {
    @Test func lockedUsersStartWithTwoFreeSpeaksPerDay() async throws {
        let harness = makeHarness()
        defer { harness.cleanup() }

        let controller = makeTTSPurchaseController(harness: harness)
        await settleAsyncWork()

        #expect(controller.isTTSUnlocked == false)
        #expect(controller.remainingFreeTTSSpeaksToday == 2)
        #expect(controller.canStartNewTTSSpeak == true)
    }

    @Test func consumingFreeSpeaksStopsAtZero() async throws {
        let harness = makeHarness()
        defer { harness.cleanup() }

        let controller = makeTTSPurchaseController(harness: harness)
        await settleAsyncWork()

        controller.consumeFreeTTSSpeakIfNeeded()
        #expect(controller.remainingFreeTTSSpeaksToday == 1)

        controller.consumeFreeTTSSpeakIfNeeded()
        #expect(controller.remainingFreeTTSSpeaksToday == 0)
        #expect(controller.canStartNewTTSSpeak == false)

        controller.consumeFreeTTSSpeakIfNeeded()
        #expect(controller.remainingFreeTTSSpeaksToday == 0)
    }

    @Test func unlockedUsersDoNotConsumeDailySpeaks() async throws {
        let harness = makeHarness(isUnlocked: true)
        defer { harness.cleanup() }

        let controller = makeTTSPurchaseController(harness: harness)
        await settleAsyncWork()

        controller.consumeFreeTTSSpeakIfNeeded()
        #expect(controller.isTTSUnlocked == true)
        #expect(controller.remainingFreeTTSSpeaksToday == TTSPurchaseController.dailyFreeSpeakLimit)
    }

    @Test func dailyUsageResetsWhenTheLocalDayChanges() async throws {
        let harness = makeHarness()
        defer { harness.cleanup() }

        let controller = makeTTSPurchaseController(harness: harness)
        await settleAsyncWork()

        controller.consumeFreeTTSSpeakIfNeeded()
        controller.consumeFreeTTSSpeakIfNeeded()
        #expect(controller.remainingFreeTTSSpeaksToday == 0)

        harness.now = Calendar.current.date(byAdding: .day, value: 1, to: harness.now)!
        controller.refreshUsageIfNeeded()

        #expect(controller.remainingFreeTTSSpeaksToday == 2)
        #expect(controller.canStartNewTTSSpeak == true)
    }

    @Test func purchaseAndRestoreFlipUnlockState() async throws {
        let harness = makeHarness()
        defer { harness.cleanup() }

        let controller = makeTTSPurchaseController(harness: harness)
        await settleAsyncWork()

        await controller.purchaseTTSUnlock()
        #expect(controller.isTTSUnlocked == true)

        harness.store.isUnlocked = false
        harness.defaults.set(false, forKey: UserDefaultsKeys.App.isTTSUnlocked)
        let secondController = makeTTSPurchaseController(harness: harness)
        await settleAsyncWork()
        #expect(secondController.isTTSUnlocked == false)

        harness.store.restoreWillUnlock = true
        await secondController.restorePurchases()
        #expect(secondController.isTTSUnlocked == true)
    }

    private func makeTTSPurchaseController(
        harness: TTSPurchaseHarness,
        bypassFreeSpeakLimitInAllDebugBuilds: Bool = false
    ) -> TTSPurchaseController {
        TTSPurchaseController(
            defaults: harness.defaults,
            store: harness.store,
            now: { harness.now },
            bypassFreeSpeakLimitInAllDebugBuilds: bypassFreeSpeakLimitInAllDebugBuilds
        )
    }

    private func makeHarness(isUnlocked: Bool = false) -> TTSPurchaseHarness {
        let suiteName = "TTSPurchaseControllerTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        let store = StubTTSUnlockStore(isUnlocked: isUnlocked)
        return TTSPurchaseHarness(
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
private final class TTSPurchaseHarness {
    let defaults: UserDefaults
    let store: StubTTSUnlockStore
    var now: Date
    private let suiteName: String

    init(defaults: UserDefaults, store: StubTTSUnlockStore, now: Date, suiteName: String) {
        self.defaults = defaults
        self.store = store
        self.now = now
        self.suiteName = suiteName
    }

    func cleanup() {
        defaults.removePersistentDomain(forName: suiteName)
    }
}

private final class StubTTSUnlockStore: TTSUnlockStore {
    var isUnlocked: Bool
    var restoreWillUnlock: Bool

    init(isUnlocked: Bool) {
        self.isUnlocked = isUnlocked
        self.restoreWillUnlock = isUnlocked
    }

    func loadUnlockProduct(productID: String) async throws -> TTSUnlockStoreProduct? {
        TTSUnlockStoreProduct(id: productID, displayName: "Unlock TTS", displayPrice: "$9.99")
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
