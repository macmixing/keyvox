import UIKit

/// Sliding a finger along the category buttons, as on the system emoji keyboard, recorded by
/// watching it (Tools/AppleKeyboardBaseline, `EmojiFrequentlyUsedProbeTests`): once the finger moves,
/// a band grows behind every button in about a fifth of a second and every button darkens; the
/// grid follows the finger a column at a time, its scroll offset in step with how far along the
/// buttons the finger is, so no emoji shows cut at its leading edge;
/// and when the finger lifts the band shrinks into the circle around the category showing in
/// about a third of a second, the grid staying where the finger left it.
extension KeyboardEmojiCategoryBar {
    enum ScrubMeasured {
        static let growDuration: TimeInterval = 0.2
        static let shrinkDuration: TimeInterval = 0.35
        /// How far inside the category buttons' row the band's ends sit.
        static let bandInset: CGFloat = 2
    }

    func configureScrub() {
        let recognizer = UIPanGestureRecognizer(target: self, action: #selector(handleScrub(_:)))
        recognizer.maximumNumberOfTouches = 1
        categoryStack.addGestureRecognizer(recognizer)
    }

    @objc private func handleScrub(_ recognizer: UIPanGestureRecognizer) {
        let location = recognizer.location(in: categoryStack)
        switch recognizer.state {
        case .began:
            beginScrub(at: location)
            followScrub(to: location)
        case .changed:
            followScrub(to: location)
        case .ended, .cancelled, .failed:
            endScrub()
        default:
            break
        }
    }

    private func beginScrub(at location: CGPoint) {
        isScrubbing = true
        let touched = categoryButtons.first { $0.button.frame.minX <= location.x && location.x < $0.button.frame.maxX }
        scrubView.frame = selectionFrame(for: touched?.category ?? selectedCategory) ?? bandFrame
        scrubView.isHidden = false
        selectionView.isHidden = true
        categoryButtons.forEach { $0.button.tintColor = .label }
        UIView.animate(withDuration: ScrubMeasured.growDuration) {
            self.scrubView.frame = self.bandFrame
        }
    }

    private func followScrub(to location: CGPoint) {
        let width = categoryStack.bounds.width
        guard width > 0 else { return }
        onScrub?(min(max(location.x / width, 0), 1))
    }

    private func endScrub() {
        guard isScrubbing else { return }
        onScrubEnded?()
        isScrubbing = false
        categoryButtons.forEach { $0.button.tintColor = .secondaryLabel }
        guard let circle = selectionFrame(for: selectedCategory) else {
            scrubView.isHidden = true
            return
        }
        UIView.animate(withDuration: ScrubMeasured.shrinkDuration, animations: {
            self.scrubView.frame = circle
        }, completion: { _ in
            guard self.isScrubbing == false else { return }
            self.scrubView.isHidden = true
            self.select(self.selectedCategory)
        })
    }

    /// The band behind every category button, in the bar's coordinates.
    private var bandFrame: CGRect {
        let row = categoryStack.frame
        let diameter = Drawn.selectionDiameter
        return CGRect(
            x: row.minX + ScrubMeasured.bandInset,
            y: row.midY - (diameter / 2),
            width: row.width - (ScrubMeasured.bandInset * 2),
            height: diameter
        )
    }
}
