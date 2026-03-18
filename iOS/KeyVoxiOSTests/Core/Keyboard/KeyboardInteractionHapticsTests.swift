import Foundation
import Testing
import UIKit
@testable import KeyVox_iOS

struct KeyboardInteractionHapticsTests {
    @Test func lightEmissionUsesSharedKeyboardHapticsSetting() {
        let defaults = makeDefaults()
        defaults.set(true, forKey: UserDefaultsKeys.keyboardHapticsEnabled)
        let lightGenerator = KeyboardImpactFeedbackGeneratorSpy()
        let mediumGenerator = KeyboardImpactFeedbackGeneratorSpy()
        let notificationGenerator = KeyboardNotificationFeedbackGeneratorSpy()
        let haptics = KeyboardInteractionHaptics(
            settingsStore: KeyboardHapticsSettingsStore(defaults: defaults),
            lightGenerator: lightGenerator,
            mediumGenerator: mediumGenerator,
            notificationGenerator: notificationGenerator
        )

        haptics.emitLightIfEnabled()

        #expect(lightGenerator.impactCount == 1)
        #expect(mediumGenerator.impactCount == 0)
        #expect(notificationGenerator.notificationTypes.isEmpty)
    }

    @Test func mediumEmissionUsesSharedKeyboardHapticsSetting() {
        let defaults = makeDefaults()
        defaults.set(true, forKey: UserDefaultsKeys.keyboardHapticsEnabled)
        let lightGenerator = KeyboardImpactFeedbackGeneratorSpy()
        let mediumGenerator = KeyboardImpactFeedbackGeneratorSpy()
        let notificationGenerator = KeyboardNotificationFeedbackGeneratorSpy()
        let haptics = KeyboardInteractionHaptics(
            settingsStore: KeyboardHapticsSettingsStore(defaults: defaults),
            lightGenerator: lightGenerator,
            mediumGenerator: mediumGenerator,
            notificationGenerator: notificationGenerator
        )

        haptics.emitMediumIfEnabled()

        #expect(lightGenerator.impactCount == 0)
        #expect(mediumGenerator.impactCount == 1)
        #expect(notificationGenerator.notificationTypes.isEmpty)
    }

    @Test func warningEmissionUsesSharedKeyboardHapticsSetting() {
        let defaults = makeDefaults()
        defaults.set(true, forKey: UserDefaultsKeys.keyboardHapticsEnabled)
        let lightGenerator = KeyboardImpactFeedbackGeneratorSpy()
        let mediumGenerator = KeyboardImpactFeedbackGeneratorSpy()
        let notificationGenerator = KeyboardNotificationFeedbackGeneratorSpy()
        let haptics = KeyboardInteractionHaptics(
            settingsStore: KeyboardHapticsSettingsStore(defaults: defaults),
            lightGenerator: lightGenerator,
            mediumGenerator: mediumGenerator,
            notificationGenerator: notificationGenerator
        )

        haptics.emitWarningIfEnabled()

        #expect(lightGenerator.impactCount == 0)
        #expect(mediumGenerator.impactCount == 0)
        #expect(notificationGenerator.notificationTypes == [.warning])
    }

    @Test func interactionHapticsDoNotEmitWhenDisabled() {
        let defaults = makeDefaults()
        defaults.set(false, forKey: UserDefaultsKeys.keyboardHapticsEnabled)
        let lightGenerator = KeyboardImpactFeedbackGeneratorSpy()
        let mediumGenerator = KeyboardImpactFeedbackGeneratorSpy()
        let notificationGenerator = KeyboardNotificationFeedbackGeneratorSpy()
        let haptics = KeyboardInteractionHaptics(
            settingsStore: KeyboardHapticsSettingsStore(defaults: defaults),
            lightGenerator: lightGenerator,
            mediumGenerator: mediumGenerator,
            notificationGenerator: notificationGenerator
        )

        haptics.emitLightIfEnabled()
        haptics.emitMediumIfEnabled()
        haptics.emitWarningIfEnabled()

        #expect(lightGenerator.impactCount == 0)
        #expect(mediumGenerator.impactCount == 0)
        #expect(notificationGenerator.notificationTypes.isEmpty)
    }

    private func makeDefaults() -> UserDefaults {
        let suiteName = "KeyboardInteractionHapticsTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        return defaults
    }
}

private final class KeyboardImpactFeedbackGeneratorSpy: KeyboardImpactFeedbackGenerating {
    var impactCount = 0

    func prepare() {}

    func impactOccurred() {
        impactCount += 1
    }
}

private final class KeyboardNotificationFeedbackGeneratorSpy: KeyboardNotificationFeedbackGenerating {
    var notificationTypes: [UINotificationFeedbackGenerator.FeedbackType] = []

    func prepare() {}

    func notificationOccurred(_ notificationType: UINotificationFeedbackGenerator.FeedbackType) {
        notificationTypes.append(notificationType)
    }
}
