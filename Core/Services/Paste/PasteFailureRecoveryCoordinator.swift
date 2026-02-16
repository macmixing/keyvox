import AppKit
import Foundation

@MainActor
final class PasteFailureRecoveryCoordinator {
    static let shared = PasteFailureRecoveryCoordinator()

    private let recoveryDuration: TimeInterval = 20
    private let commandVRestoreDelay: TimeInterval = 0.15
    private let commandVDebounceInterval: TimeInterval = 0.12
    private let progressTickInterval: TimeInterval = 0.05

    private var startedAt: Date?
    private var restoreClipboard: (() -> Void)?
    private var timer: Timer?
    private var localKeyMonitor: Any?
    private var globalKeyMonitor: Any?
    private var lastCommandVAt: Date = .distantPast
    private var generation: Int = 0

    private init() {}

    func startRecovery(restoreClipboard: @escaping () -> Void) {
        cancelActiveRecoveryIfNeeded()
        generation += 1
        startedAt = Date()
        self.restoreClipboard = restoreClipboard
        lastCommandVAt = .distantPast

        WarningManager.shared.showPasteFailureRecovery(
            progress: 1.0,
            onDismiss: { [weak self] in
                self?.completeRecovery(reason: .manualDismiss)
            }
        )

        installKeyMonitors()
        installProgressTimer()
    }

    func cancelActiveRecoveryIfNeeded() {
        guard isActive else { return }
        completeRecovery(reason: .replacedByNewSession)
    }

    private var isActive: Bool {
        startedAt != nil && restoreClipboard != nil
    }

    private enum CompletionReason {
        case commandVDetected
        case escapePressed
        case manualDismiss
        case timeout
        case replacedByNewSession
    }

    private func completeRecovery(reason: CompletionReason) {
        guard isActive else { return }

        let completionGeneration = generation
        let restore = restoreClipboard

        clearSessionState()
        WarningManager.shared.hidePasteFailureRecovery()

        guard let restore else { return }

        switch reason {
        case .commandVDetected:
            DispatchQueue.main.asyncAfter(deadline: .now() + commandVRestoreDelay) { [weak self] in
                guard let self, self.generation == completionGeneration else { return }
                restore()
            }
        case .escapePressed, .manualDismiss, .timeout, .replacedByNewSession:
            restore()
        }
    }

    private func clearSessionState() {
        timer?.invalidate()
        timer = nil
        startedAt = nil
        restoreClipboard = nil
        removeKeyMonitors()
    }

    private func installProgressTimer() {
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: progressTickInterval, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.handleProgressTick()
            }
        }
        if let timer {
            RunLoop.main.add(timer, forMode: .common)
        }
    }

    private func handleProgressTick() {
        guard let startedAt else { return }
        let elapsed = Date().timeIntervalSince(startedAt)
        let remaining = max(0, recoveryDuration - elapsed)
        let progress = max(0, min(1, remaining / recoveryDuration))
        WarningManager.shared.updatePasteFailureRecovery(progress: progress)

        if remaining <= 0 {
            completeRecovery(reason: .timeout)
        }
    }

    private func installKeyMonitors() {
        removeKeyMonitors()

        localKeyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            Task { @MainActor [weak self] in
                self?.handleKeyDown(event)
            }
            return event
        }

        globalKeyMonitor = NSEvent.addGlobalMonitorForEvents(matching: .keyDown) { [weak self] event in
            Task { @MainActor [weak self] in
                self?.handleKeyDown(event)
            }
        }
    }

    private func removeKeyMonitors() {
        if let localKeyMonitor {
            NSEvent.removeMonitor(localKeyMonitor)
            self.localKeyMonitor = nil
        }
        if let globalKeyMonitor {
            NSEvent.removeMonitor(globalKeyMonitor)
            self.globalKeyMonitor = nil
        }
    }

    private func handleKeyDown(_ event: NSEvent) {
        guard isActive else { return }

        if event.keyCode == 53 { // Escape
            completeRecovery(reason: .escapePressed)
            return
        }

        guard event.modifierFlags.contains(.command) else { return }
        guard event.charactersIgnoringModifiers?.lowercased() == "v" else { return }

        let now = Date()
        guard now.timeIntervalSince(lastCommandVAt) >= commandVDebounceInterval else { return }
        lastCommandVAt = now

        completeRecovery(reason: .commandVDetected)
    }
}
