import Foundation
import Testing
@testable import KeyVox_iOS

struct KeyboardRescuedDictationStoreTests {
    @Test(arguments: [false, true])
    func keepsASavedDictationUntilCleared(hasPublishedIdentity: Bool) {
        withDefaults { defaults in
            let dictation = KeyboardRescuedDictationStore.Dictation(
                text: UUID().uuidString,
                artifactID: hasPublishedIdentity ? UUID() : nil,
                styleIdentifier: hasPublishedIdentity ? UUID().uuidString : nil
            )
            KeyboardRescuedDictationStore(defaults: defaults).save(dictation)

            let laterStore = KeyboardRescuedDictationStore(defaults: defaults)
            #expect(laterStore.dictation == dictation)

            laterStore.clear()

            #expect(KeyboardRescuedDictationStore(defaults: defaults).dictation == nil)
        }
    }

    @MainActor
    @Test func announcesEachChange() {
        withDefaults { defaults in
            let store = KeyboardRescuedDictationStore(defaults: defaults)
            var changes = 0
            let observer = NotificationCenter.default.addObserver(
                forName: KeyboardRescuedDictationStore.didChangeNotification,
                object: store,
                queue: nil
            ) { _ in changes += 1 }
            defer { NotificationCenter.default.removeObserver(observer) }

            store.save(KeyboardRescuedDictationStore.Dictation(text: UUID().uuidString, artifactID: nil, styleIdentifier: nil))
            store.clear()
            store.clear()

            #expect(changes == 2)
        }
    }

    private func withDefaults(_ body: (UserDefaults) -> Void) {
        let suiteName = "KeyboardRescuedDictationStoreTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { defaults.removePersistentDomain(forName: suiteName) }
        body(defaults)
    }
}
