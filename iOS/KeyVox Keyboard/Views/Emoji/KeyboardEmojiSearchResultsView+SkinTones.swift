import KeyVoxEmoji
import UIKit

/// Holding a search result, as on the system emoji keyboard's search, recorded by watching it
/// (Tools/AppleKeyboardBaseline, `EmojiFrequentlyUsedProbeTests`): after as long as a letter key
/// takes to open its popup, a result that comes in skin tones opens its picker, which stays open
/// once the finger lifts; the next tap on a choice types it and remembers it for that emoji, and a
/// tap anywhere else closes the picker without typing.
extension KeyboardEmojiSearchResultsView {
    func configureSkinTonePicker() {
        let recognizer = UILongPressGestureRecognizer(target: self, action: #selector(handleHold(_:)))
        recognizer.minimumPressDuration = KeyboardStyle.heldKeyPopupHoldDuration
        collectionView.addGestureRecognizer(recognizer)
        pickerTapCatcher.backgroundColor = .clear
        pickerTapCatcher.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(handlePickerTap(_:))))
    }

    /// Closes the open skin-tone picker, if any, without typing.
    func closeSkinTonePicker() {
        heldResult = nil
        skinTonePicker.dismiss()
        pickerTapCatcher.removeFromSuperview()
    }

    @objc private func handleHold(_ recognizer: UILongPressGestureRecognizer) {
        guard recognizer.state == .began,
              let container = popupContainer,
              let keyboard = container.superview,
              let indexPath = collectionView.indexPathForItem(at: recognizer.location(in: collectionView)),
              let cell = collectionView.cellForItem(at: indexPath) else {
            return
        }
        let emoji = results[indexPath.item]
        // The two-person emoji's picker, two rows of tones, is not drawn yet; holding one opens
        // nothing, as holding an emoji without skin tones does.
        guard emoji.skinToneVariants.count == 5 else { return }
        let layout = KeyboardEmojiSearchSkinTonePickerLayout(
            heldResult: collectionView.convert(cell.frame, to: container),
            toneCount: emoji.skinToneVariants.count,
            keyboard: container.bounds
        )
        let choices = [emoji.text] + emoji.skinToneVariants
        if skinTonePicker.superview !== container {
            skinTonePicker.removeFromSuperview()
            container.addSubview(skinTonePicker)
        }
        skinTonePicker.frame = container.bounds
        skinTonePicker.present(
            panel: layout.panelFrame,
            stem: layout.stemFrame,
            divider: layout.dividerFrame,
            choiceCenters: layout.choiceCenters,
            choices: choices,
            font: pickerFont,
            style: .searchResult
        )
        pickerTapCatcher.frame = container.frame
        keyboard.insertSubview(pickerTapCatcher, belowSubview: container)
        heldResult = (emoji, layout, choices)
        onSkinTonePickerOpened?()
    }

    @objc private func handlePickerTap(_ recognizer: UITapGestureRecognizer) {
        guard let held = heldResult, let container = popupContainer else {
            closeSkinTonePicker()
            return
        }
        let choice = held.layout.choice(tappedAt: recognizer.location(in: container))
        closeSkinTonePicker()
        guard let choice else { return }
        let version = held.choices[choice]
        onSkinToneChosen?(held.emoji.text, version)
        onEmojiSelected?(version)
    }
}
