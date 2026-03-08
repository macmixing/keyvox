import Foundation

extension iOSTranscriptionManager {
    func armIdleTimeout() {
        cancelIdleTimeout()

        guard isSessionActive,
              !sessionDisablePending,
              let idleTimeout = sessionPolicy.idleTimeout else {
            return
        }

        let expirationDate = Date().addingTimeInterval(idleTimeout)
        sessionExpirationDate = expirationDate
        idleTimeoutTask = Task { [weak self] in
            let duration = UInt64(idleTimeout * 1_000_000_000)
            try? await Task.sleep(nanoseconds: duration)
            await self?.handleIdleTimeoutFired()
        }
    }

    func cancelIdleTimeout() {
        idleTimeoutTask?.cancel()
        idleTimeoutTask = nil
        sessionExpirationDate = nil
    }

    func handleIdleTimeoutFired() async {
        guard isSessionActive, !sessionDisablePending, state == .idle else { return }
        await completeSessionShutdown()
    }

    func finishAndDisableSessionIfNeeded() async {
        if sessionDisablePending && state == .idle {
            await completeSessionShutdown()
        } else if isSessionActive && state == .idle {
            armIdleTimeout()
        }
    }

    func completeSessionShutdown() async {
        cancelIdleTimeout()

        do {
            try recorder.stopMonitoring()
            isSessionActive = false
            sessionDisablePending = false
            sessionExpirationDate = nil
        } catch {
            lastErrorMessage = error.localizedDescription
        }
    }
}
