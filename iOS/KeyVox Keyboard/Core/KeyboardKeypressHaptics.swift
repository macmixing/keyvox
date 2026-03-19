import UIKit

protocol KeyboardImpactFeedbackGenerating: AnyObject {
    func prepare()
    func impactOccurred()
}

final class KeyboardImpactFeedbackGeneratorAdapter: KeyboardImpactFeedbackGenerating {
    private let generator: UIImpactFeedbackGenerator
    private let intensity: CGFloat

    init(
        style: UIImpactFeedbackGenerator.FeedbackStyle = .light,
        intensity: CGFloat = 0.80
    ) {
        generator = UIImpactFeedbackGenerator(style: style)
        self.intensity = intensity
    }

    func prepare() {
        generator.prepare()
    }

    func impactOccurred() {
        generator.impactOccurred(intensity: intensity)
    }
}

final class KeyboardKeypressHaptics {
    private let settingsStore: KeyboardHapticsSettingsStore
    private let generator: any KeyboardImpactFeedbackGenerating

    init(
        settingsStore: KeyboardHapticsSettingsStore = KeyboardHapticsSettingsStore(),
        generator: any KeyboardImpactFeedbackGenerating = KeyboardImpactFeedbackGeneratorAdapter()
    ) {
        self.settingsStore = settingsStore
        self.generator = generator
        self.generator.prepare()
    }

    func emitKeypressIfEnabled() {
        guard settingsStore.isKeypressHapticsEnabled else { return }
        generator.impactOccurred()
        generator.prepare()
    }
}
