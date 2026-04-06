import UIKit

protocol KeyboardNotificationFeedbackGenerating: AnyObject {
    func prepare()
    func notificationOccurred(_ notificationType: UINotificationFeedbackGenerator.FeedbackType)
}

final class KeyboardNotificationFeedbackGeneratorAdapter: KeyboardNotificationFeedbackGenerating {
    private let generator = UINotificationFeedbackGenerator()

    func prepare() {
        generator.prepare()
    }

    func notificationOccurred(_ notificationType: UINotificationFeedbackGenerator.FeedbackType) {
        generator.notificationOccurred(notificationType)
    }
}

final class KeyboardInteractionHaptics {
    private let settingsStore: KeyboardHapticsSettingsStore
    private let lightGenerator: any KeyboardImpactFeedbackGenerating
    private let mediumGenerator: any KeyboardImpactFeedbackGenerating
    private let notificationGenerator: any KeyboardNotificationFeedbackGenerating

    init(
        settingsStore: KeyboardHapticsSettingsStore = KeyboardHapticsSettingsStore(),
        lightGenerator: any KeyboardImpactFeedbackGenerating = KeyboardImpactFeedbackGeneratorAdapter(
            style: .light,
            intensity: 0.80
        ),
        mediumGenerator: any KeyboardImpactFeedbackGenerating = KeyboardImpactFeedbackGeneratorAdapter(
            style: .medium,
            intensity: 0.90
        ),
        notificationGenerator: any KeyboardNotificationFeedbackGenerating = KeyboardNotificationFeedbackGeneratorAdapter()
    ) {
        self.settingsStore = settingsStore
        self.lightGenerator = lightGenerator
        self.mediumGenerator = mediumGenerator
        self.notificationGenerator = notificationGenerator
        self.lightGenerator.prepare()
        self.mediumGenerator.prepare()
        self.notificationGenerator.prepare()
    }

    func emitLightIfEnabled() {
        guard settingsStore.isKeypressHapticsEnabled else { return }
        lightGenerator.impactOccurred()
        lightGenerator.prepare()
    }

    func emitMediumIfEnabled() {
        guard settingsStore.isKeypressHapticsEnabled else { return }
        mediumGenerator.impactOccurred()
        mediumGenerator.prepare()
    }

    func emitWarningIfEnabled() {
        guard settingsStore.isKeypressHapticsEnabled else { return }
        notificationGenerator.notificationOccurred(.warning)
        notificationGenerator.prepare()
    }
}
