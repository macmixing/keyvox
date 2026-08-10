import Foundation
import KeyVoxStyleRewrite
import Testing
@testable import KeyVox_iOS

@MainActor
struct KeyVoxVibesAccessMatrixTests {
    @Test func noTrialMissingModelOpensIntroWithModelGatedCTA() {
        let matrix = resolve(accessState: .noTrialStartedNotUnlocked, modelState: .missing)

        #expect(matrix.mainCardContent == .trialOffer)
        #expect(matrix.cardControl == .tryNow)
        #expect(matrix.cardAction == .openIntroFlow)
        #expect(matrix.destinationStart == .sceneA)
        #expect(matrix.dynamicText == .none)
        #expect(matrix.destinationCTA == .introModelMissing)
    }

    @Test func noTrialInstalledModelOpensIntroWithTryNowCTA() {
        let matrix = resolve(accessState: .noTrialStartedNotUnlocked, modelState: .installed)

        #expect(matrix.mainCardContent == .trialOffer)
        #expect(matrix.cardControl == .tryNow)
        #expect(matrix.cardAction == .openIntroFlow)
        #expect(matrix.destinationStart == .sceneA)
        #expect(matrix.dynamicText == .none)
        #expect(matrix.destinationCTA == .tryNow)
    }

    @Test func activeTrialMissingModelOpensSceneCRecovery() {
        let matrix = resolve(accessState: .trialActive, modelState: .missing)

        #expect(matrix.mainCardContent == .downloadRequired)
        #expect(matrix.cardControl == .download)
        #expect(matrix.cardAction == .openSceneCRecovery)
        #expect(matrix.destinationStart == .sceneC)
        #expect(matrix.dynamicText == .sceneCTrialRemaining)
        #expect(matrix.destinationCTA == .introModelMissing)
    }

    @Test func activeTrialInstalledModelShowsVibeSelector() {
        let matrix = resolve(accessState: .trialActive, modelState: .installed, selectedVibe: .polished)

        #expect(matrix.mainCardContent == .selectedVibe(.polished))
        #expect(matrix.cardControl == .change)
        #expect(matrix.cardAction == .openVibeSelector)
        #expect(matrix.destinationStart == .vibeSelector)
        #expect(matrix.dynamicText == .mainCardTrialRemaining)
        #expect(matrix.destinationCTA == .none)
    }

    @Test func expiredTrialMissingModelOpensUnlockScene() {
        let matrix = resolve(accessState: .trialExpiredNotUnlocked, modelState: .missing)

        #expect(matrix.mainCardContent == .unlockOffer)
        #expect(matrix.cardControl == .unlock)
        #expect(matrix.cardAction == .openUnlockScene)
        #expect(matrix.destinationStart == .unlockScene)
        #expect(matrix.dynamicText == .unlockSubtitle)
        #expect(matrix.destinationCTA == .unlockPurchase)
    }

    @Test func expiredTrialInstalledModelOpensUnlockFlow() {
        let matrix = resolve(accessState: .trialExpiredNotUnlocked, modelState: .installed)

        #expect(matrix.mainCardContent == .unlockOffer)
        #expect(matrix.cardControl == .unlock)
        #expect(matrix.cardAction == .openUnlockFlow)
        #expect(matrix.destinationStart == .featureUnlockFlow)
        #expect(matrix.dynamicText == .unlockSubtitle)
        #expect(matrix.destinationCTA == .unlockPurchase)
    }

    @Test func unlockedMissingModelOpensContinueRecovery() {
        let matrix = resolve(accessState: .unlocked, modelState: .missing)

        #expect(matrix.mainCardContent == .downloadRequired)
        #expect(matrix.cardControl == .download)
        #expect(matrix.cardAction == .openUnlockedModelRecovery)
        #expect(matrix.destinationStart == .unlockScene)
        #expect(matrix.dynamicText == .unlockSubtitle)
        #expect(matrix.destinationCTA == .continueWhenVibesAIReady)
    }

    @Test func unlockedInstalledModelShowsVibeSelector() {
        let matrix = resolve(accessState: .unlocked, modelState: .installed, selectedVibe: .chill)

        #expect(matrix.mainCardContent == .selectedVibe(.chill))
        #expect(matrix.cardControl == .change)
        #expect(matrix.cardAction == .openVibeSelector)
        #expect(matrix.destinationStart == .vibeSelector)
        #expect(matrix.dynamicText == .none)
        #expect(matrix.destinationCTA == .none)
    }

    @Test func keyboardMissingModelForUnlockedUserPresentsContinueRecovery() async {
        let suiteName = "KeyVoxVibesAccessMatrixTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { defaults.removePersistentDomain(forName: suiteName) }
        defaults.set(true, forKey: UserDefaultsKeys.App.isVibesUnlocked)

        let controller = KeyVoxVibesPurchaseController(
            defaults: defaults,
            store: UnlockedVibesStore(),
            setSelectedVibe: { _ in }
        )
        for _ in 0..<5 {
            await Task.yield()
        }

        controller.presentKeyboardModelRecoverySheet()

        #expect(
            controller.sheetPresentation == KeyVoxVibesPurchaseController.SheetPresentation.unlock(
                initialScene: KeyVoxVibesSheetView.Scene.unlock,
                primaryAction: KeyVoxVibesSheetView.UnlockPrimaryAction.continueWhenVibesAIReady
            )
        )
    }

    @Test func derivedAccessStateMatchesTrialAndUnlockFlags() {
        #expect(
            KeyVoxVibesAccessMatrix.accessState(
                isVibesUnlocked: false,
                hasTrialStarted: false,
                isTrialActive: false
            ) == .noTrialStartedNotUnlocked
        )
        #expect(
            KeyVoxVibesAccessMatrix.accessState(
                isVibesUnlocked: false,
                hasTrialStarted: true,
                isTrialActive: true
            ) == .trialActive
        )
        #expect(
            KeyVoxVibesAccessMatrix.accessState(
                isVibesUnlocked: false,
                hasTrialStarted: true,
                isTrialActive: false
            ) == .trialExpiredNotUnlocked
        )
        #expect(
            KeyVoxVibesAccessMatrix.accessState(
                isVibesUnlocked: true,
                hasTrialStarted: false,
                isTrialActive: false
            ) == .unlocked
        )
    }

    @Test func modelStateMatchesInstallAvailability() {
        #expect(KeyVoxVibesAccessMatrix.modelState(isVibesAIInstalled: false) == .missing)
        #expect(KeyVoxVibesAccessMatrix.modelState(isVibesAIInstalled: true) == .installed)
    }

    private func resolve(
        accessState: KeyVoxVibesAccessMatrix.AccessState,
        modelState: KeyVoxVibesAccessMatrix.ModelState,
        selectedVibe: StyleRewriteStyle = .casual
    ) -> KeyVoxVibesAccessMatrix {
        KeyVoxVibesAccessMatrix.resolve(
            accessState: accessState,
            modelState: modelState,
            selectedVibe: selectedVibe
        )
    }
}

private final class UnlockedVibesStore: StoreUnlockStore {
    func loadUnlockProduct(productID _: String) async throws -> StoreUnlockProduct? {
        nil
    }

    func isUnlocked(productID _: String) async throws -> Bool {
        true
    }

    func purchase(productID _: String) async throws -> Bool {
        true
    }

    func restore(productID _: String) async throws -> Bool {
        true
    }
}
