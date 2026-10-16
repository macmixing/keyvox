import KeyVoxEmoji
import UIKit

/// Holding an emoji on the emoji page, as on the system emoji keyboard, recorded by watching it
/// (Tools/AppleKeyboardBaseline, `EmojiFrequentlyUsedProbeTests`): after as long as a letter key
/// takes to open its popup, an emoji that comes in skin tones opens its picker, and lifting the
/// finger on a choice types it and remembers it for that emoji; lifting anywhere else, or holding an
/// emoji without skin tones, types nothing. An emoji of two people opens a picker that stays open
/// for taps (`KeyboardEmojiTwoPersonPickerView`).
extension KeyboardEmojiPageView {
    func configureSkinTonePicker() {
        let recognizer = UILongPressGestureRecognizer(target: self, action: #selector(handleHold(_:)))
        recognizer.minimumPressDuration = KeyboardStyle.heldKeyPopupHoldDuration
        collectionView.addGestureRecognizer(recognizer)
    }

    /// Closes the two-person picker, if open, and gives its container's touches back to the keys.
    func closeTwoPersonPicker() {
        twoPersonPicker.dismiss()
        popupContainer?.isUserInteractionEnabled = false
    }

    @objc private func handleHold(_ recognizer: UILongPressGestureRecognizer) {
        guard let container = popupContainer else { return }
        let location = recognizer.location(in: container)
        switch recognizer.state {
        case .began:
            beginHold(at: recognizer.location(in: collectionView), in: container)
        case .changed:
            followHold(to: location)
        case .ended:
            endHold(at: location)
        default:
            cancelHold()
        }
    }

    private func beginHold(at point: CGPoint, in container: UIView) {
        guard let indexPath = collectionView.indexPathForItem(at: point),
              let cell = collectionView.cellForItem(at: indexPath) else {
            return
        }
        let emoji = sections[indexPath.section].emoji[indexPath.item]
        if let tones = EmojiTwoPersonTones(emoji) {
            presentTwoPersonPicker(emoji, tones: tones, at: collectionView.convert(cell.center, to: container), in: container)
            return
        }
        guard emoji.skinToneVariants.count == 5 else { return }
        let layout = KeyboardEmojiSkinTonePickerLayout(
            emojiCenter: collectionView.convert(cell.center, to: container),
            toneCount: emoji.skinToneVariants.count,
            width: container.bounds.width,
            rowPitch: gridLayout.geometry.rowPitch
        )
        let choices = [emoji.text] + emoji.skinToneVariants
        if skinTonePicker.superview !== container {
            skinTonePicker.removeFromSuperview()
            container.addSubview(skinTonePicker)
        }
        skinTonePicker.frame = container.bounds
        skinTonePicker.present(
            panel: layout.panelFrame,
            stem: nil,
            divider: layout.dividerFrame,
            choiceCenters: layout.choiceCenters,
            choices: choices,
            font: emojiFont,
            style: .page
        )
        heldEmoji = (emoji, layout, choices, nil)
        onSkinTonePickerOpened?()
    }

    private func presentTwoPersonPicker(_ emoji: Emoji, tones: EmojiTwoPersonTones, at center: CGPoint, in container: UIView) {
        if twoPersonPicker.superview !== container {
            twoPersonPicker.removeFromSuperview()
            container.addSubview(twoPersonPicker)
        }
        twoPersonPicker.frame = container.bounds
        twoPersonPicker.onChosen = { [weak self] version in
            self?.closeTwoPersonPicker()
            self?.onSkinToneChosen?(emoji.text, version)
            self?.onEmojiSelected?(version)
        }
        twoPersonPicker.onDismissed = { [weak self] in
            self?.closeTwoPersonPicker()
        }
        twoPersonPicker.present(
            emoji,
            tones: tones,
            chosenVersion: chosenTones[emoji.text],
            layout: KeyboardEmojiTwoPersonPickerLayout(emojiCenter: center, bounds: container.bounds),
            font: emojiFont,
            style: .page
        )
        // The picker stays open after the finger lifts, so its container takes the taps meant for it.
        container.isUserInteractionEnabled = true
        onSkinTonePickerOpened?()
    }

    private func followHold(to location: CGPoint) {
        guard let held = heldEmoji else { return }
        let choice = held.layout.choice(at: location)
        guard choice != held.choice else { return }
        heldEmoji?.choice = choice
        skinTonePicker.select(choice)
        if choice != nil {
            onSkinToneHighlighted?()
        }
    }

    private func endHold(at location: CGPoint) {
        followHold(to: location)
        guard let held = heldEmoji else { return }
        cancelHold()
        guard let choice = held.choice else { return }
        let version = held.choices[choice]
        onSkinToneChosen?(held.emoji.text, version)
        onEmojiSelected?(version)
    }

    private func cancelHold() {
        heldEmoji = nil
        skinTonePicker.dismiss()
    }
}
