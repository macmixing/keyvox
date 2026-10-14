import KeyVoxEmoji
import UIKit

/// The emoji search, as on the system emoji keyboard, recorded by watching it
/// (Tools/AppleKeyboardBaseline, `EmojiFrequentlyUsedProbeTests`): the field on the emoji page
/// starts it over the letter keys, with a row of results that makes the keyboard taller; the keys
/// type into the search instead of the text, and until something is typed the results are the
/// Frequently Used emoji. A result tapped types into the text and the search stays; done ends the
/// search on the letter keys, as does the keyboard going away.
extension KeyboardViewController {
    func configureEmojiSearch(in rootView: KeyboardRootView) {
        let fieldView = rootView.emojiSearchFieldView
        fieldView.text = emojiSearchText
        fieldView.onBegin = { [weak self] in
            self?.beginEmojiSearch()
        }
        fieldView.onClear = { [weak self] in
            self?.setEmojiSearchText("")
        }
        let resultsView = rootView.emojiSearchResultsView
        resultsView.popupContainer = popupOverlayView
        resultsView.chosenTones = emojiSkinToneStore.chosenTones
        resultsView.onEmojiSelected = { [weak self] emoji in
            self?.typeEmoji(emoji)
        }
        resultsView.onSkinTonePickerOpened = { [weak self] in
            self?.characterKeyHaptics.emitKeypressIfEnabled()
        }
        resultsView.onSkinToneChosen = { [weak self] emoji, version in
            self?.chooseEmojiSkinTone(version, for: emoji)
        }
        showEmojiSearchResults()
    }

    func unconfigureEmojiSearch(in rootView: KeyboardRootView) {
        rootView.emojiSearchFieldView.onBegin = nil
        rootView.emojiSearchFieldView.onClear = nil
        let resultsView = rootView.emojiSearchResultsView
        resultsView.closeSkinTonePicker()
        resultsView.popupContainer = nil
        resultsView.onEmojiSelected = nil
        resultsView.onSkinTonePickerOpened = nil
        resultsView.onSkinToneChosen = nil
    }

    /// Ends the search on the letter keys without reading the text, for a keyboard going away.
    func leaveEmojiSearch() {
        guard emojiPanel == .searching else { return }
        rootContainerView?.emojiSearchResultsView.closeSkinTonePicker()
        setEmojiSearchText("")
        symbolPage = .letters
        emojiPanel = .closed
    }

    /// Takes a key while searching: characters and space go into the search, delete takes from
    /// it, and done ends it. Returns nil for the keys that work as on the letter keys: shift and
    /// the page keys.
    func handleEmojiSearchActivation(_ activation: KeyboardKeyActivation) -> Bool? {
        switch activation.kind {
        case let .character(value):
            updateSymbolPage(for: activation.kind)
            setEmojiSearchText(emojiSearchText + value)
            if value.first?.isLetter == true {
                letterCaseController.consumeTypedLetter()
                applyLetterCase()
            }
            return true
        case .space:
            updateSymbolPage(for: activation.kind)
            keypressHaptics.emitKeypressIfEnabled()
            setEmojiSearchText(emojiSearchText + " ")
            return true
        case .delete:
            // The delete key's press plays its haptic when the finger lifts; repeats play theirs now.
            if activation.isRepeat {
                keypressHaptics.emitKeypressIfEnabled()
            }
            guard emojiSearchText.isEmpty == false else { return false }
            setEmojiSearchText(String(emojiSearchText.dropLast()))
            return true
        case .emojiSearchDone:
            keypressHaptics.emitKeypressIfEnabled()
            endEmojiSearch()
            return true
        default:
            return nil
        }
    }

    /// Deletes whole words from the search for a held delete key. Returns false when there was
    /// nothing to delete.
    func deleteEmojiSearchWords(_ count: Int) -> Bool {
        var text = emojiSearchText
        for _ in 0..<count {
            while text.last?.isWhitespace == true {
                text.removeLast()
            }
            while let last = text.last, last.isWhitespace == false {
                text.removeLast()
            }
        }
        guard text != emojiSearchText else { return false }
        keypressHaptics.emitKeypressIfEnabled()
        setEmojiSearchText(text)
        return true
    }

    private func beginEmojiSearch() {
        guard emojiPanel == .browsing, let rootView = rootContainerView else { return }
        keypressHaptics.emitKeypressIfEnabled()
        emojiDeleteRepeatController.cancel()
        // The Frequently Used emoji as the page showed them.
        emojiSearchFrequentlyUsed = rootView.emojiPageView.sections.first { $0.category == .frequentlyUsed }?.emoji ?? []
        setEmojiSearchText("")
        symbolPage = .letters
        // The system keyboard's search starts in lowercase.
        letterCaseController.reset()
        emojiPanel = .searching
        applyLetterCase()
        showEmojiSearchResults()
        KeyboardEmojiSearchIndex.shared.load { [weak self] in
            self?.showEmojiSearchResults()
        }
    }

    private func endEmojiSearch() {
        leaveEmojiSearch()
        handleTypingContextChange()
    }

    private func setEmojiSearchText(_ text: String) {
        emojiSearchText = text
        rootContainerView?.emojiSearchFieldView.text = text
        showEmojiSearchResults()
    }

    /// Shows the emoji the search finds that the phone draws, or before a word is typed the
    /// Frequently Used emoji.
    private func showEmojiSearchResults() {
        guard emojiPanel == .searching, let resultsView = rootContainerView?.emojiSearchResultsView else { return }
        guard emojiSearchText.contains(where: { $0.isWhitespace == false }) else {
            resultsView.show(emojiSearchFrequentlyUsed)
            return
        }
        resultsView.show(KeyboardEmojiSearchIndex.shared.results(for: emojiSearchText).compactMap {
            KeyboardEmojiSections.shared.emoji($0)
        })
    }
}
