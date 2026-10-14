import KeyVoxEmoji
import UIKit

/// Holding an emoji on the emoji page, as on the system emoji keyboard, recorded by watching it
/// (Tools/AppleKeyboardBaseline, `EmojiFrequentlyUsedProbeTests`): after as long as a letter key
/// takes to open its popup, an emoji that comes in skin tones opens its picker, and lifting the
/// finger on a choice types it and remembers it for that emoji; lifting anywhere else, or holding an
/// emoji without skin tones, types nothing.
extension KeyboardEmojiPageView {
    func configureSkinTonePicker() {
        let recognizer = UILongPressGestureRecognizer(target: self, action: #selector(handleHold(_:)))
        recognizer.minimumPressDuration = KeyboardStyle.heldKeyPopupHoldDuration
        collectionView.addGestureRecognizer(recognizer)
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
        // The two-person emoji's picker, two rows of tones, is not drawn yet; holding one types
        // nothing, as holding an emoji without skin tones does.
        guard emoji.skinToneVariants.count == 5 else { return }
        let layout = KeyboardEmojiSkinTonePickerLayout(
            emojiCenter: collectionView.convert(cell.center, to: container),
            toneCount: emoji.skinToneVariants.count,
            width: container.bounds.width
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
            font: emojiFont,
            style: .page
        )
        heldEmoji = (emoji, layout, choices, nil)
        onSkinTonePickerOpened?()
    }

    private func followHold(to location: CGPoint) {
        guard let held = heldEmoji else { return }
        let choice = held.layout.choice(at: location)
        guard choice != held.choice else { return }
        heldEmoji?.choice = choice
        skinTonePicker.select(choice)
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
