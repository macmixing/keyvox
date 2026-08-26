import Foundation
import Testing
@testable import KeyVox_iOS

struct KeyboardCompactKeysTests {
    @Test @MainActor func keyboardControllerDefaultsToFullKeys() {
        let controller = KeyboardViewController(nibName: nil, bundle: nil)

        #expect(controller.keysMode == .full)
    }

    @Test func modesProvideExplicitKeyboardAndGridHeights() {
        #expect(KeyboardKeysMode.full.keyboardHeight == 286)
        #expect(KeyboardKeysMode.compact.keyboardHeight == 174)
        #expect(KeyboardKeysMode.full.keyGridHeight == 216)
        #expect(KeyboardKeysMode.compact.keyGridHeight == 104)
    }

    @Test func compactLayoutReusesTheFinalTwoPrimaryRows() {
        let fullRows = KeyboardSymbolLayout.rows(for: .primary, keysMode: .full)
        let compactRows = KeyboardSymbolLayout.rows(for: .primary, keysMode: .compact)

        #expect(compactRows.count == 2)
        #expect(compactRows[0][0].kind == .restoreFullKeyboard)
        #expect(compactRows[0][0].systemImageName == "keyboard")
        #expect(Array(compactRows[0].dropFirst()) == Array(fullRows[2].dropFirst()))
        #expect(compactRows[1] == fullRows[3])
    }

    @Test func compactKeysAvailabilityDefaultsOnAndCanBeDisabled() {
        let suiteName = "KeyboardCompactKeysTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        let store = KeyboardAppSettingsStore(defaults: defaults)

        #expect(store.isCompactKeysEnabled)

        defaults.set(false, forKey: UserDefaultsKeys.compactKeysEnabled)

        #expect(store.isCompactKeysEnabled == false)
    }

    @Test func compactKeysSelectionSurvivesASettingsStoreRecreation() {
        let suiteName = "KeyboardCompactKeysTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        let firstStore = KeyboardAppSettingsStore(defaults: defaults)

        #expect(firstStore.isCompactKeysActive == false)
        firstStore.setCompactKeysActive(true)

        let recreatedStore = KeyboardAppSettingsStore(defaults: defaults)
        let restoredMode = KeyboardKeysMode.resolve(
            isCompactKeysEnabled: recreatedStore.isCompactKeysEnabled,
            isCompactKeysActive: recreatedStore.isCompactKeysActive
        )

        #expect(restoredMode == .compact)
    }

    @Test func disablingCompactKeysOverridesAStoredCompactSelection() {
        #expect(
            KeyboardKeysMode.resolve(
                isCompactKeysEnabled: false,
                isCompactKeysActive: true
            ) == .full
        )
    }

    @Test @MainActor func completedHoldSuppressesTheOrdinaryKeyActivation() {
        let controller = KeyboardCompactKeysHoldController(activationHoldDuration: 0.01)
        var activationCount = 0

        controller.begin(onCompactKeysTrigger: true) {
            activationCount += 1
            return true
        }
        RunLoop.main.run(until: Date().addingTimeInterval(0.03))

        #expect(activationCount == 1)
        #expect(controller.end())
    }

    @Test @MainActor func leavingTheTriggerKeyCancelsThePendingHold() {
        let controller = KeyboardCompactKeysHoldController(activationHoldDuration: 0.01)
        var activationCount = 0

        controller.begin(onCompactKeysTrigger: true) {
            activationCount += 1
            return true
        }
        controller.update(isStillOnCompactKeysTrigger: false)
        RunLoop.main.run(until: Date().addingTimeInterval(0.03))

        #expect(activationCount == 0)
        #expect(controller.end() == false)
    }

    @Test @MainActor func unavailableCompactModeLeavesTheOrdinaryKeyActivationUnsuppressed() {
        let controller = KeyboardCompactKeysHoldController(activationHoldDuration: 0.01)

        controller.begin(onCompactKeysTrigger: true) {
            false
        }
        RunLoop.main.run(until: Date().addingTimeInterval(0.03))

        #expect(controller.end() == false)
    }
}
