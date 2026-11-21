import Foundation

/// Offers a dictation that was finished in the background after its keyboard went away: the
/// suggestion bar shows it as one suggestion until it is tapped, the user types, or the keyboard
/// is dismissed.
extension KeyboardViewController {
    /// Shows the kept dictation, if any, and shows one that finishes while the keyboard is up.
    func startOfferingRescuedDictation() {
        if rescuedDictationObserver == nil {
            rescuedDictationObserver = NotificationCenter.default.addObserver(
                forName: KeyboardRescuedDictationStore.didChangeNotification,
                object: nil,
                queue: .main
            ) { [weak self] _ in
                self?.refreshRescuedDictation()
            }
        }
        refreshRescuedDictation()
    }

    /// The keyboard is being dismissed: a dictation it offered is not offered again.
    func stopOfferingRescuedDictation() {
        removeRescuedDictationObserver()
        if isShowingRescuedDictation {
            rescuedDictationStore.clear()
        }
        isShowingRescuedDictation = false
        rootContainerView?.suggestionBarView.showRescuedDictation(nil)
    }

    func removeRescuedDictationObserver() {
        if let rescuedDictationObserver {
            NotificationCenter.default.removeObserver(rescuedDictationObserver)
        }
        rescuedDictationObserver = nil
    }

    /// The user typed, so the kept dictation is no longer offered.
    func dismissRescuedDictation() {
        guard isShowingRescuedDictation else { return }
        rescuedDictationStore.clear()
    }

    func handleRescuedDictationSelected() {
        guard let dictation = rescuedDictationStore.dictation else { return }
        interactionHaptics.emitLightIfEnabled()
        rescuedDictationStore.clear()
        insertDictation(dictation.text, artifactID: dictation.artifactID, styleIdentifier: dictation.styleIdentifier)
    }

    private func refreshRescuedDictation() {
        let text = rescuedDictationStore.dictation?.text
        isShowingRescuedDictation = text != nil
        rootContainerView?.suggestionBarView.showRescuedDictation(text)
        updateUI()
    }
}
