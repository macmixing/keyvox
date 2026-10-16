import KeyVoxEmoji
import UIKit

/// The emoji page: the emoji key opens it in the key grid's place, an emoji tapped there types as
/// a key does, its delete key deletes as the grid's does, and its bar's first key returns to the
/// keys the user types on: Compact Keys or the 123 page for those who use them, the letters
/// otherwise.
extension KeyboardViewController {
    func openEmojiPage() {
        keypressHaptics.emitKeypressIfEnabled()
        emojiPanel = .browsing
        loadEmojiPage()
    }

    /// Binds `rootView`'s emoji page, open when the page was open before the views were built again.
    func configureEmojiPage(in rootView: KeyboardRootView) {
        let emojiPageView = rootView.emojiPageView
        if emojiPanel == .browsing {
            loadEmojiPage()
        }
        emojiPageView.popupContainer = popupOverlayView
        emojiPageView.chosenTones = emojiSkinToneStore.chosenTones
        emojiPageView.onEmojiSelected = { [weak self] emoji in
            self?.typeEmoji(emoji)
        }
        emojiPageView.onSkinTonePickerOpened = { [weak self] in
            self?.characterKeyHaptics.emitKeypressIfEnabled()
        }
        emojiPageView.onSkinToneHighlighted = { [weak self] in
            self?.characterKeyHaptics.emitKeypressIfEnabled()
        }
        emojiPageView.onCategoryReached = { [weak self] in
            self?.characterKeyHaptics.emitKeypressIfEnabled()
        }
        emojiPageView.onSkinToneChosen = { [weak self] emoji, version in
            self?.chooseEmojiSkinTone(version, for: emoji)
        }
        emojiPageView.onLetters = { [weak self] in
            self?.closeEmojiPage()
        }
        emojiPageView.onDeleteBegan = { [weak self] in
            self?.beginEmojiPageDelete()
        }
        emojiPageView.onDeleteEnded = { [weak self] in
            self?.endEmojiPageDelete()
        }
    }

    func unconfigureEmojiPage(_ emojiPageView: KeyboardEmojiPageView) {
        emojiPageView.closeTwoPersonPicker()
        emojiPageView.onEmojiSelected = nil
        emojiPageView.onSkinTonePickerOpened = nil
        emojiPageView.onSkinToneHighlighted = nil
        emojiPageView.onCategoryReached = nil
        emojiPageView.onSkinToneChosen = nil
        emojiPageView.popupContainer = nil
        emojiPageView.onLetters = nil
        emojiPageView.onDeleteBegan = nil
        emojiPageView.onDeleteEnded = nil
        emojiDeleteRepeatController.cancel()
    }

    /// Shows the page's sections with the emoji the user used most as they stand now; the
    /// section changes only when the page opens again, as on the system keyboard.
    private func loadEmojiPage() {
        KeyboardEmojiSections.shared.load { [weak self] in
            guard let self else { return }
            let frequentlyUsed = emojiFrequentlyUsedStore.frequentlyUsed
            rootContainerView?.emojiPageView.show(
                frequentlyUsed: { KeyboardEmojiSections.shared.frequentlyUsedEmoji(frequentlyUsed, count: $0) },
                catalog: KeyboardEmojiSections.shared.catalog
            )
        }
    }

    private func closeEmojiPage() {
        keypressHaptics.emitKeypressIfEnabled()
        emojiDeleteRepeatController.cancel()
        // Compact Keys stay as they were; otherwise the page the return key named.
        if keysMode == .full {
            symbolPage = emojiPageReturnKey == .numberSymbols ? .primary : .letters
        }
        emojiPanel = .closed
    }

    /// The key that leaves the emoji page: 123 back to Compact Keys or to the 123 page the user
    /// opens on, ABC back to the letters otherwise.
    var emojiPageReturnKey: KeyboardKeyKind {
        keysMode == .compact || appSettingsStore.opensOnNumberPage ? .numberSymbols : .abc
    }

    /// The emoji the suggestion bar offers for `word`, in the skin tones the user chose, the ones
    /// they used most first, as on the system keyboard.
    func barEmoji(for word: String) -> [String] {
        guard appSettingsStore.isEmojiKeyboardEnabled else { return [] }
        let emoji = KeyboardEmojiPredictionsIndex.shared.emoji(for: word).map { emojiSkinToneStore.chosenTones[$0] ?? $0 }
        return emojiFrequentlyUsedStore.frequentlyUsed.ordering(emoji)
    }

    /// Remembers `version` for `emoji`, which the page and the search then show it in.
    func chooseEmojiSkinTone(_ version: String, for emoji: String) {
        emojiSkinToneStore.choose(version, for: emoji)
        rootContainerView?.emojiPageView.chosenTones = emojiSkinToneStore.chosenTones
        rootContainerView?.emojiSearchResultsView.chosenTones = emojiSkinToneStore.chosenTones
    }

    /// Types `emoji` as a key types its character, exactly as shown, with the key's haptic.
    func typeEmoji(_ emoji: String) {
        var page = symbolPage
        guard textInputController.handleKeyActivation(
            .character(emoji),
            typesExactly: true,
            symbolPage: &page
        ) else {
            return
        }
        characterKeyHaptics.emitKeypressIfEnabled()
        emojiFrequentlyUsedStore.recordUse(of: emoji)
        KeyboardEmojiPredictionsIndex.shared.recordTypedEmoji()
        handleTypingContextChange()
    }

    /// Deletes as a held delete key on the grid does; the press plays its haptic when the finger
    /// lifts, repeats as they delete.
    private func beginEmojiPageDelete() {
        var isRepeat = false
        emojiDeleteRepeatController.begin { [weak self] granularity in
            guard let self else { return false }
            defer { isRepeat = true }
            if case let .words(count) = granularity {
                return self.handleDeleteWords(count)
            }
            var page = self.symbolPage
            let didDelete = self.textInputController.handleKeyActivation(
                .delete,
                emitsKeypress: isRepeat,
                symbolPage: &page
            )
            if didDelete {
                self.handleTypingContextChange()
            }
            return didDelete
        }
    }

    private func endEmojiPageDelete() {
        emojiDeleteRepeatController.cancel()
        keypressHaptics.emitKeypressIfEnabled()
    }
}
