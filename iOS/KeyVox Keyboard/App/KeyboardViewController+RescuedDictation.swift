import Foundation
import UIKit

/// Offers a dictation that was finished in the background after its keyboard went away: the
/// suggestion bar shows it as one suggestion until it is tapped, or, once it has been on screen,
/// until the user types or the keyboard is dismissed.
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
        if hasShownRescuedDictation {
            rescuedDictationStore.clear()
        }
        isShowingRescuedDictation = false
        hasShownRescuedDictation = false
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
        guard hasShownRescuedDictation else { return }
        rescuedDictationStore.clear()
    }

    /// Records that the offered dictation is on screen, which only some pages and modes allow.
    func noteRescuedDictationVisibility() {
        guard isShowingRescuedDictation, rootContainerView?.suggestionBarView.isHidden == false else { return }
        hasShownRescuedDictation = true
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
        if text == nil {
            hasShownRescuedDictation = false
        }
        rootContainerView?.suggestionBarView.showRescuedDictation(text)
        updateUI()
    }
}
