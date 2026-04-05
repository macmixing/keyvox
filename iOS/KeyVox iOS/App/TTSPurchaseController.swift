import Combine
import Foundation
import StoreKit

struct TTSUnlockStoreProduct: Equatable {
    let id: String
    let displayName: String
    let displayPrice: String
}

protocol TTSUnlockStore {
    func loadUnlockProduct(productID: String) async throws -> TTSUnlockStoreProduct?
    func isUnlocked(productID: String) async throws -> Bool
    func purchase(productID: String) async throws -> Bool
    func restore(productID: String) async throws -> Bool
}

struct AppStoreTTSUnlockStore: TTSUnlockStore {
    func loadUnlockProduct(productID: String) async throws -> TTSUnlockStoreProduct? {
        let products = try await Product.products(for: [productID])
        guard let product = products.first(where: { $0.id == productID }) else {
            return nil
        }

        return TTSUnlockStoreProduct(
            id: product.id,
            displayName: product.displayName,
            displayPrice: product.displayPrice
        )
    }

    func isUnlocked(productID: String) async throws -> Bool {
        for await verificationResult in Transaction.currentEntitlements {
            guard case .verified(let transaction) = verificationResult else { continue }
            guard transaction.productID == productID else { continue }
            guard transaction.revocationDate == nil else { continue }
            return true
        }

        return false
    }

    func purchase(productID: String) async throws -> Bool {
        let products = try await Product.products(for: [productID])
        guard let product = products.first(where: { $0.id == productID }) else {
            return false
        }

        let result = try await product.purchase()

        switch result {
        case .success(let verificationResult):
            guard case .verified(let transaction) = verificationResult else {
                return false
            }
            await transaction.finish()
            return true
        case .userCancelled, .pending:
            return false
        @unknown default:
            return false
        }
    }

    func restore(productID: String) async throws -> Bool {
        try await AppStore.sync()
        return try await isUnlocked(productID: productID)
    }
}

@MainActor
protocol TTSPurchaseGating {
    var isTTSUnlocked: Bool { get }
    var remainingFreeTTSSpeaksToday: Int { get }
    var canStartNewTTSSpeak: Bool { get }
    func refreshUsageIfNeeded()
    func presentUnlockSheet()
    func dismissUnlockSheet()
    func consumeFreeTTSSpeakIfNeeded()
}

@MainActor
final class TTSPurchaseController: ObservableObject, TTSPurchaseGating {
    nonisolated static let unlockProductID = "com.cueit.keyvox.tts.unlock"
    nonisolated static let dailyFreeSpeakLimit = 2

    @Published private(set) var isTTSUnlocked: Bool
    @Published private(set) var remainingFreeTTSSpeaksToday: Int = TTSPurchaseController.dailyFreeSpeakLimit
    @Published private(set) var unlockProduct: TTSUnlockStoreProduct?
    @Published private(set) var isStoreActionInFlight = false
    @Published var isUnlockSheetPresented = false
    @Published var storeMessage: String?

    private let defaults: UserDefaults
    private let store: any TTSUnlockStore
    private let now: () -> Date
    private let calendar: Calendar
    private let bypassFreeSpeakLimitInDebug: Bool
    private let bypassFreeSpeakLimitInAllDebugBuilds: Bool
    private var storeRefreshGeneration: UInt64 = 0

    init(
        defaults: UserDefaults,
        store: any TTSUnlockStore,
        now: @escaping () -> Date = Date.init,
        calendar: Calendar = .current,
        bypassFreeSpeakLimit: Bool = false,
        bypassFreeSpeakLimitInAllDebugBuilds: Bool = true
    ) {
        self.defaults = defaults
        self.store = store
        self.now = now
        self.calendar = calendar
        self.bypassFreeSpeakLimitInDebug = bypassFreeSpeakLimit
        self.bypassFreeSpeakLimitInAllDebugBuilds = bypassFreeSpeakLimitInAllDebugBuilds
        self.isTTSUnlocked = defaults.bool(forKey: UserDefaultsKeys.App.isTTSUnlocked)
        refreshUsageState()

        Task { @MainActor [weak self] in
            await self?.refreshStoreState()
        }
    }

    convenience init(
        defaults: UserDefaults,
        now: @escaping () -> Date = Date.init,
        calendar: Calendar = .current,
        bypassFreeSpeakLimit: Bool = false,
        bypassFreeSpeakLimitInAllDebugBuilds: Bool = true
    ) {
        self.init(
            defaults: defaults,
            store: AppStoreTTSUnlockStore(),
            now: now,
            calendar: calendar,
            bypassFreeSpeakLimit: bypassFreeSpeakLimit,
            bypassFreeSpeakLimitInAllDebugBuilds: bypassFreeSpeakLimitInAllDebugBuilds
        )
    }

    var canStartNewTTSSpeak: Bool {
        if isFreeSpeakLimitBypassedForCurrentBuild {
            return true
        }
        return isTTSUnlocked || currentRemainingFreeSpeakCount > 0
    }

    func refreshUsageIfNeeded() {
        refreshUsageState()
    }

    func presentUnlockSheet() {
        refreshUsageIfNeeded()
        isUnlockSheetPresented = true
    }

    func dismissUnlockSheet() {
        isUnlockSheetPresented = false
    }

    func refreshStoreState() async {
        refreshUsageIfNeeded()
        guard isStoreActionInFlight == false else { return }
        let refreshGeneration = beginStoreRefresh()

        let unlocked = await refreshedUnlockState(productID: Self.unlockProductID)
        guard canApplyStoreRefresh(generation: refreshGeneration) else { return }
        applyUnlockState(unlocked)

        do {
            let product = try await store.loadUnlockProduct(productID: Self.unlockProductID)
            guard canApplyStoreRefresh(generation: refreshGeneration) else { return }
            unlockProduct = product
            storeMessage = nil
        } catch {
            guard canApplyStoreRefresh(generation: refreshGeneration) else { return }
            unlockProduct = nil
            storeMessage = error.localizedDescription
        }
    }

    func purchaseTTSUnlock() async {
        guard isStoreActionInFlight == false else { return }
        refreshUsageIfNeeded()
        invalidateStoreRefreshes()
        isStoreActionInFlight = true
        defer { isStoreActionInFlight = false }

        do {
            let unlocked = try await store.purchase(productID: Self.unlockProductID)
            if unlocked {
                applyUnlockState(true)
                isUnlockSheetPresented = false
                storeMessage = nil
            }
        } catch {
            storeMessage = error.localizedDescription
        }
    }

    func restorePurchases() async {
        guard isStoreActionInFlight == false else { return }
        refreshUsageIfNeeded()
        invalidateStoreRefreshes()
        isStoreActionInFlight = true
        defer { isStoreActionInFlight = false }

        do {
            let unlocked = try await store.restore(productID: Self.unlockProductID)
            applyUnlockState(unlocked)
            if unlocked {
                isUnlockSheetPresented = false
                storeMessage = nil
            }
        } catch {
            storeMessage = error.localizedDescription
        }
    }

    func consumeFreeTTSSpeakIfNeeded() {
        guard isFreeSpeakLimitBypassedForCurrentBuild == false else { return }
        refreshUsageState()
        guard isTTSUnlocked == false else { return }
        guard remainingFreeTTSSpeaksToday > 0 else { return }

        let newCount = usedFreeSpeaksToday + 1
        defaults.set(newCount, forKey: UserDefaultsKeys.App.ttsFreeSpeakUsageCount)
        refreshUsageState()
    }

    private var currentUsageDayStart: TimeInterval {
        calendar.startOfDay(for: now()).timeIntervalSince1970
    }

    private var storedUsageDayStart: TimeInterval {
        defaults.double(forKey: UserDefaultsKeys.App.ttsFreeSpeakUsageDayStart)
    }

    private var usedFreeSpeaksToday: Int {
        defaults.integer(forKey: UserDefaultsKeys.App.ttsFreeSpeakUsageCount)
    }

    private var currentRemainingFreeSpeakCount: Int {
        if isFreeSpeakLimitBypassedForCurrentBuild {
            return Self.dailyFreeSpeakLimit
        }

        if isTTSUnlocked {
            return Self.dailyFreeSpeakLimit
        }

        let usedCount = storedUsageDayStart == currentUsageDayStart ? usedFreeSpeaksToday : 0
        return max(0, Self.dailyFreeSpeakLimit - usedCount)
    }

    private var isFreeSpeakLimitBypassedForCurrentBuild: Bool {
        #if DEBUG
        bypassFreeSpeakLimitInAllDebugBuilds || bypassFreeSpeakLimitInDebug
        #else
        bypassFreeSpeakLimitInDebug
        #endif
    }

    private func refreshUsageState() {
        if storedUsageDayStart != currentUsageDayStart {
            defaults.set(currentUsageDayStart, forKey: UserDefaultsKeys.App.ttsFreeSpeakUsageDayStart)
            defaults.set(0, forKey: UserDefaultsKeys.App.ttsFreeSpeakUsageCount)
        }

        remainingFreeTTSSpeaksToday = currentRemainingFreeSpeakCount
    }

    private func applyUnlockState(_ unlocked: Bool) {
        isTTSUnlocked = unlocked
        defaults.set(unlocked, forKey: UserDefaultsKeys.App.isTTSUnlocked)
        refreshUsageState()
    }

    private func currentEntitlementIsUnlocked(productID: String) async -> Bool {
        for await verificationResult in Transaction.currentEntitlements {
            guard case .verified(let transaction) = verificationResult else { continue }
            guard transaction.productID == productID else { continue }
            guard transaction.revocationDate == nil else { continue }
            return true
        }

        return false
    }

    private func refreshedUnlockState(productID: String) async -> Bool {
        if store is AppStoreTTSUnlockStore {
            return await currentEntitlementIsUnlocked(productID: productID)
        }

        do {
            return try await store.isUnlocked(productID: productID)
        } catch {
            return isTTSUnlocked
        }
    }

    private func beginStoreRefresh() -> UInt64 {
        storeRefreshGeneration &+= 1
        return storeRefreshGeneration
    }

    private func invalidateStoreRefreshes() {
        storeRefreshGeneration &+= 1
    }

    private func canApplyStoreRefresh(generation: UInt64) -> Bool {
        isStoreActionInFlight == false && storeRefreshGeneration == generation
    }
}
