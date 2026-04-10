import SwiftUI
import UIKit

protocol AppHapticsEmitting {
    func emit(_ event: AppHapticEvent)
    func light()
    func medium()
    func selection()
    func success()
    func warning()
}

final class AppHaptics: AppHapticsEmitting {
    static let shared = AppHaptics()

    private let lightGenerator = UIImpactFeedbackGenerator(style: .light)
    private let mediumGenerator = UIImpactFeedbackGenerator(style: .medium)
    private let selectionGenerator = UISelectionFeedbackGenerator()
    private let notificationGenerator = UINotificationFeedbackGenerator()

    init() {
        prepareGenerators()
    }

    func emit(_ event: AppHapticEvent) {
        switch event {
        case .light:
            lightGenerator.impactOccurred()
            lightGenerator.prepare()
        case .medium:
            mediumGenerator.impactOccurred()
            mediumGenerator.prepare()
        case .selection:
            selectionGenerator.selectionChanged()
            selectionGenerator.prepare()
        case .success:
            notificationGenerator.notificationOccurred(.success)
            notificationGenerator.prepare()
        case .warning:
            notificationGenerator.notificationOccurred(.warning)
            notificationGenerator.prepare()
        }
    }

    func light() {
        emit(.light)
    }

    func medium() {
        emit(.medium)
    }

    func selection() {
        emit(.selection)
    }

    func success() {
        emit(.success)
    }

    func warning() {
        emit(.warning)
    }

    private func prepareGenerators() {
        lightGenerator.prepare()
        mediumGenerator.prepare()
        selectionGenerator.prepare()
        notificationGenerator.prepare()
    }
}

private struct AppHapticsEnvironmentKey: EnvironmentKey {
    static let defaultValue = AppHaptics.shared
}

extension EnvironmentValues {
    var appHaptics: AppHaptics {
        get { self[AppHapticsEnvironmentKey.self] }
        set { self[AppHapticsEnvironmentKey.self] = newValue }
    }
}
