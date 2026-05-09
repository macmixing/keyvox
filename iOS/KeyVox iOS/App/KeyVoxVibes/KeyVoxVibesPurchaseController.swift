import Combine
import Foundation
import KeyVoxStyleRewrite
import StoreKit

@MainActor
final class KeyVoxVibesPurchaseController: ObservableObject {
    enum SheetPresentation: Equatable {
        case intro(KeyVoxVibesSheetView.IntroPresentation)
        case info(KeyVoxVibesSheetView.IntroPresentation)
        case unlock(initialScene: KeyVoxVibesSheetView.Scene = .b)
    }

    nonisolated static let unlockProductID = "com.cueit.keyvox.vibes.unlocked"
    nonisolated static let trialDuration: TimeInterval = 24 * 60 * 60

    @Published private(set) var isVibesUnlocked: Bool
    @Published private(set) var unlockProduct: StoreUnlockProduct?
    @Published private(set) var isStoreActionInFlight = false
    @Published private(set) var sheetPresentation: SheetPresentation?
    @Published private var trialCountdownTick: UInt64 = 0
    @Published var storeMessage: String?

    private let defaults: UserDefaults
    private let store: any StoreUnlockStore
    private let now: () -> Date
    private let bypassTrialInDebug: Bool
    private let trialDurationOverride: TimeInterval?
    private let setSelectedVibe: (StyleRewriteStyle) -> Void
    private var storeRefreshGeneration: UInt64 = 0
    private var transactionUpdatesTask: Task<Void, Never>?
    private var trialCountdownTask: Task<Void, Never>?

    init(
        defaults: UserDefaults,
        store: any StoreUnlockStore,
        now: @escaping () -> Date = Date.init,
        bypassTrial: Bool = false,
        trialDurationOverride: TimeInterval? = nil,
        resetTrial: Bool = false,
        setSelectedVibe: @escaping (StyleRewriteStyle) -> Void
    ) {
        self.defaults = defaults
        self.store = store
        self.now = now
        self.bypassTrialInDebug = bypassTrial
        self.trialDurationOverride = trialDurationOverride
        self.setSelectedVibe = setSelectedVibe
        if Self.shouldResetTrialForCurrentBuild(resetTrial) {
            defaults.removeObject(forKey: UserDefaultsKeys.App.vibesTrialStartedAt)
            defaults.removeObject(forKey: UserDefaultsKeys.App.debugVibesTrialDuration)
        }
        self.isVibesUnlocked = defaults.bool(forKey: UserDefaultsKeys.App.isVibesUnlocked)
        refreshTrialStateIfNeeded()
        startTrialCountdownIfNeeded()
        startListeningForTransactionUpdatesIfNeeded()

        Task { @MainActor [weak self] in
            await self?.refreshStoreState()
        }
    }

    convenience init(
        defaults: UserDefaults,
        now: @escaping () -> Date = Date.init,
        bypassTrial: Bool = false,
        trialDurationOverride: TimeInterval? = nil,
        resetTrial: Bool = false,
        setSelectedVibe: @escaping (StyleRewriteStyle) -> Void
    ) {
        self.init(
            defaults: defaults,
            store: AppStoreUnlockStore(),
            now: now,
            bypassTrial: bypassTrial,
            trialDurationOverride: trialDurationOverride,
            resetTrial: resetTrial,
            setSelectedVibe: setSelectedVibe
        )
    }

    deinit {
        transactionUpdatesTask?.cancel()
        trialCountdownTask?.cancel()
    }

    var hasTrialStarted: Bool {
        trialStartedAt != nil
    }

    var isTrialActive: Bool {
        trialRemaining > 0
    }

    var hasTrialEnded: Bool {
        hasTrialStarted && !isTrialActive && !isVibesUnlocked
    }

    var canUseVibes: Bool {
        isTrialBypassedForCurrentBuild || isVibesUnlocked || isTrialActive
    }

    var trialRemaining: TimeInterval {
        guard let trialStartedAt else { return 0 }
        let elapsed = now().timeIntervalSince(trialStartedAt)
        return max(0, effectiveTrialDuration - elapsed)
    }

    var trialRemainingText: String {
        let remainingSeconds = Int(ceil(trialRemaining))
        let hours = remainingSeconds / 3600
        let minutes = max(0, (remainingSeconds % 3600) / 60)
        guard hours > 0 else {
            return "\(minutes)m"
        }

        return "\(hours)h \(minutes)m"
    }

    func refreshStoreState() async {
        refreshTrialStateIfNeeded()
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

    func startTrial() {
        guard isVibesUnlocked == false else { return }
        guard hasTrialStarted == false else {
            if isTrialActive {
                dismissSheet()
            } else {
                presentUnlockSheet()
            }
            return
        }

        defaults.set(now(), forKey: UserDefaultsKeys.App.vibesTrialStartedAt)
        persistDebugTrialDurationIfNeeded()
        defaults.set(true, forKey: UserDefaultsKeys.App.hasInteractedWithKeyVoxVibes)
        publishTrialCountdownTick()
        startTrialCountdownIfNeeded()
        dismissSheet()
    }

    func presentIntroSheet() {
        presentIntroSheet(presentation: .full)
    }

    func presentIntroSheet(presentation: KeyVoxVibesSheetView.IntroPresentation) {
        refreshTrialStateIfNeeded()
        guard isVibesUnlocked == false else {
            dismissSheet()
            return
        }

        if hasTrialStarted {
            presentUnlockSheet()
        } else {
            sheetPresentation = .intro(presentation)
        }
    }

    func presentUnlockSheet(initialScene: KeyVoxVibesSheetView.Scene = .b) {
        refreshTrialStateIfNeeded()
        guard isVibesUnlocked == false else {
            dismissSheet()
            return
        }

        sheetPresentation = .unlock(initialScene: initialScene)
    }

    func presentModelRecoverySheet() {
        refreshTrialStateIfNeeded()

        if isVibesUnlocked {
            sheetPresentation = .unlock(initialScene: .unlock)
        } else {
            sheetPresentation = .intro(.trialStart)
        }
    }

    func presentHelpSheet() {
        refreshTrialStateIfNeeded()

        if isVibesUnlocked {
            sheetPresentation = .info(.usageOnly)
        } else if hasTrialStarted {
            sheetPresentation = .unlock(initialScene: .b)
        } else {
            sheetPresentation = .intro(.full)
        }
    }

    func dismissSheet() {
        sheetPresentation = nil
    }

    func purchaseVibesUnlock() async {
        guard isStoreActionInFlight == false else { return }
        refreshTrialStateIfNeeded()
        invalidateStoreRefreshes()
        isStoreActionInFlight = true
        defer { isStoreActionInFlight = false }

        do {
            let unlocked = try await store.purchase(productID: Self.unlockProductID)
            if unlocked {
                applyUnlockState(true)
                dismissSheet()
                storeMessage = nil
            }
        } catch {
            storeMessage = error.localizedDescription
        }
    }

    func restorePurchases() async {
        guard isStoreActionInFlight == false else { return }
        refreshTrialStateIfNeeded()
        invalidateStoreRefreshes()
        isStoreActionInFlight = true
        defer { isStoreActionInFlight = false }

        do {
            let unlocked = try await store.restore(productID: Self.unlockProductID)
            applyUnlockState(unlocked)
            if unlocked {
                dismissSheet()
                storeMessage = nil
            }
        } catch {
            storeMessage = error.localizedDescription
        }
    }

    func refreshTrialStateIfNeeded() {
        publishTrialCountdownTick()
        guard isTrialBypassedForCurrentBuild == false else { return }
        guard isVibesUnlocked == false else { return }
        guard hasTrialStarted else { return }
        guard isTrialActive == false else {
            startTrialCountdownIfNeeded()
            return
        }
        setSelectedVibe(.none)
        trialCountdownTask?.cancel()
        trialCountdownTask = nil
    }

    func markVibesInteracted() {
        defaults.set(true, forKey: UserDefaultsKeys.App.hasInteractedWithKeyVoxVibes)
    }

    private var trialStartedAt: Date? {
        defaults.object(forKey: UserDefaultsKeys.App.vibesTrialStartedAt) as? Date
    }

    private var effectiveTrialDuration: TimeInterval {
        #if DEBUG
        if let trialDurationOverride {
            return trialDurationOverride
        }

        let storedDebugDuration = defaults.double(forKey: UserDefaultsKeys.App.debugVibesTrialDuration)
        if storedDebugDuration > 0 {
            return storedDebugDuration
        }
        #endif

        return Self.trialDuration
    }

    private func persistDebugTrialDurationIfNeeded() {
        #if DEBUG
        if let trialDurationOverride {
            defaults.set(trialDurationOverride, forKey: UserDefaultsKeys.App.debugVibesTrialDuration)
        }
        #endif
    }

    private func startTrialCountdownIfNeeded() {
        guard trialCountdownTask == nil else { return }
        guard isVibesUnlocked == false else { return }
        guard isTrialBypassedForCurrentBuild == false else { return }
        guard hasTrialStarted, isTrialActive else { return }

        trialCountdownTask = Task { @MainActor [weak self] in
            guard let self else { return }

            while Task.isCancelled == false {
                try? await Task.sleep(for: .seconds(1))
                guard Task.isCancelled == false else { return }

                self.publishTrialCountdownTick()
                if self.isTrialActive == false {
                    self.refreshTrialStateIfNeeded()
                    return
                }
            }
        }
    }

    private func publishTrialCountdownTick() {
        trialCountdownTick &+= 1
    }

    private var isTrialBypassedForCurrentBuild: Bool {
        #if DEBUG
        bypassTrialInDebug
        #else
        false
        #endif
    }

    private static func shouldResetTrialForCurrentBuild(_ resetTrial: Bool) -> Bool {
        #if DEBUG
        resetTrial
        #else
        false
        #endif
    }

    private func applyUnlockState(_ unlocked: Bool) {
        isVibesUnlocked = unlocked
        defaults.set(unlocked, forKey: UserDefaultsKeys.App.isVibesUnlocked)
        if unlocked {
            trialCountdownTask?.cancel()
            trialCountdownTask = nil
        } else {
            refreshTrialStateIfNeeded()
        }
    }

    private func refreshedUnlockState(productID: String) async -> Bool {
        do {
            return try await store.isUnlocked(productID: productID)
        } catch {
            return isVibesUnlocked
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

    private func startListeningForTransactionUpdatesIfNeeded() {
        guard store is AppStoreUnlockStore else { return }
        guard transactionUpdatesTask == nil else { return }

        transactionUpdatesTask = Task { [weak self] in
            for await verificationResult in Transaction.updates {
                guard let self else { return }

                switch verificationResult {
                case .verified(let transaction):
                    let isMatchingUnlock = transaction.productID == Self.unlockProductID
                    let isUnlocked = isMatchingUnlock && transaction.revocationDate == nil
                    if isMatchingUnlock {
                        await MainActor.run {
                            self.applyUnlockState(isUnlocked)
                        }
                        await transaction.finish()
                    }
                case .unverified:
                    break
                }
            }
        }
    }
}
