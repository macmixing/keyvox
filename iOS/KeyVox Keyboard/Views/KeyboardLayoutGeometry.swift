import UIKit

enum KeyboardLayoutGeometry {
    final class TopRowAccessoryLayout {
        private weak var cancelButton: UIView?
        private weak var capsLockButton: UIView?
        private weak var speakButton: UIView?
        private weak var keyGridView: KeyboardKeyGridView?
        private let cancelButtonLeadingConstraint: NSLayoutConstraint
        private let capsLockButtonTrailingConstraint: NSLayoutConstraint
        private let cancelButtonCenterYConstraint: NSLayoutConstraint
        private let capsLockButtonCenterYConstraint: NSLayoutConstraint
        private let cancelButtonWidthConstraint: NSLayoutConstraint
        private let cancelButtonHeightConstraint: NSLayoutConstraint
        private let capsLockButtonWidthConstraint: NSLayoutConstraint
        private let capsLockButtonHeightConstraint: NSLayoutConstraint

        private var cancelButtonLandscapeCenterXConstraint: NSLayoutConstraint?
        private var cancelButtonLandscapeBottomConstraint: NSLayoutConstraint?
        private var cancelButtonLandscapeWidthConstraint: NSLayoutConstraint?
        private var cancelButtonLandscapeHeightConstraint: NSLayoutConstraint?
        private var capsLockButtonLandscapeCenterXConstraint: NSLayoutConstraint?
        private var capsLockButtonLandscapeBottomConstraint: NSLayoutConstraint?
        private var capsLockButtonLandscapeWidthConstraint: NSLayoutConstraint?
        private var capsLockButtonLandscapeHeightConstraint: NSLayoutConstraint?
        private weak var cancelLandscapeReferenceView: UIView?
        private weak var capsLandscapeReferenceView: UIView?
        private var speakButtonCenterXConstraint: NSLayoutConstraint?
        private var speakButtonBottomConstraint: NSLayoutConstraint?
        private var speakButtonWidthConstraint: NSLayoutConstraint?
        private var speakButtonHeightConstraint: NSLayoutConstraint?
        private weak var speakReferenceView: UIView?
        private var speakButtonUsesLandscapeHeight = false

        init(
            cancelButton: UIView,
            capsLockButton: UIView,
            speakButton: UIView,
            keyGridView: KeyboardKeyGridView,
            cancelButtonLeadingConstraint: NSLayoutConstraint,
            capsLockButtonTrailingConstraint: NSLayoutConstraint,
            cancelButtonCenterYConstraint: NSLayoutConstraint,
            capsLockButtonCenterYConstraint: NSLayoutConstraint,
            cancelButtonWidthConstraint: NSLayoutConstraint,
            cancelButtonHeightConstraint: NSLayoutConstraint,
            capsLockButtonWidthConstraint: NSLayoutConstraint,
            capsLockButtonHeightConstraint: NSLayoutConstraint
        ) {
            self.cancelButton = cancelButton
            self.capsLockButton = capsLockButton
            self.speakButton = speakButton
            self.keyGridView = keyGridView
            self.cancelButtonLeadingConstraint = cancelButtonLeadingConstraint
            self.capsLockButtonTrailingConstraint = capsLockButtonTrailingConstraint
            self.cancelButtonCenterYConstraint = cancelButtonCenterYConstraint
            self.capsLockButtonCenterYConstraint = capsLockButtonCenterYConstraint
            self.cancelButtonWidthConstraint = cancelButtonWidthConstraint
            self.cancelButtonHeightConstraint = cancelButtonHeightConstraint
            self.capsLockButtonWidthConstraint = capsLockButtonWidthConstraint
            self.capsLockButtonHeightConstraint = capsLockButtonHeightConstraint
        }

        func update(isLandscape: Bool) {
            guard let keyGridView else { return }

            if let speakButton,
               let currentSpeakReferenceView = keyGridView.topRowKeyView(for: .nine),
               speakReferenceView !== currentSpeakReferenceView || speakButtonUsesLandscapeHeight != isLandscape {
                NSLayoutConstraint.deactivate([
                    speakButtonCenterXConstraint,
                    speakButtonBottomConstraint,
                    speakButtonWidthConstraint,
                    speakButtonHeightConstraint,
                ].compactMap { $0 })

                speakButtonCenterXConstraint = speakButton.centerXAnchor.constraint(equalTo: currentSpeakReferenceView.centerXAnchor)
                speakButtonBottomConstraint = speakButton.bottomAnchor.constraint(
                    equalTo: currentSpeakReferenceView.topAnchor,
                    constant: -KeyboardStyle.keyboardRowSpacing
                )
                speakButtonWidthConstraint = speakButton.widthAnchor.constraint(equalTo: currentSpeakReferenceView.widthAnchor)
                speakButtonHeightConstraint = isLandscape
                    ? speakButton.heightAnchor.constraint(equalTo: currentSpeakReferenceView.heightAnchor)
                    : speakButton.heightAnchor.constraint(equalTo: currentSpeakReferenceView.widthAnchor)
                speakReferenceView = currentSpeakReferenceView
                speakButtonUsesLandscapeHeight = isLandscape

                NSLayoutConstraint.activate([
                    speakButtonCenterXConstraint!,
                    speakButtonBottomConstraint!,
                    speakButtonWidthConstraint!,
                    speakButtonHeightConstraint!,
                ])
            }

            if !isLandscape {
                NSLayoutConstraint.deactivate([
                    cancelButtonLandscapeCenterXConstraint,
                    cancelButtonLandscapeBottomConstraint,
                    cancelButtonLandscapeWidthConstraint,
                    cancelButtonLandscapeHeightConstraint,
                    capsLockButtonLandscapeCenterXConstraint,
                    capsLockButtonLandscapeBottomConstraint,
                    capsLockButtonLandscapeWidthConstraint,
                    capsLockButtonLandscapeHeightConstraint,
                ].compactMap { $0 })

                cancelButtonLandscapeCenterXConstraint = nil
                cancelButtonLandscapeBottomConstraint = nil
                cancelButtonLandscapeWidthConstraint = nil
                cancelButtonLandscapeHeightConstraint = nil
                capsLockButtonLandscapeCenterXConstraint = nil
                capsLockButtonLandscapeBottomConstraint = nil
                capsLockButtonLandscapeWidthConstraint = nil
                capsLockButtonLandscapeHeightConstraint = nil
                cancelLandscapeReferenceView = nil
                capsLandscapeReferenceView = nil

                cancelButtonLeadingConstraint.isActive = true
                cancelButtonCenterYConstraint.isActive = true
                cancelButtonWidthConstraint.isActive = true
                cancelButtonHeightConstraint.isActive = true
                capsLockButtonTrailingConstraint.isActive = true
                capsLockButtonCenterYConstraint.isActive = true
                capsLockButtonWidthConstraint.isActive = true
                capsLockButtonHeightConstraint.isActive = true
                return
            }

            cancelButtonLeadingConstraint.isActive = false
            cancelButtonCenterYConstraint.isActive = false
            cancelButtonWidthConstraint.isActive = false
            cancelButtonHeightConstraint.isActive = false
            capsLockButtonTrailingConstraint.isActive = false
            capsLockButtonCenterYConstraint.isActive = false
            capsLockButtonWidthConstraint.isActive = false
            capsLockButtonHeightConstraint.isActive = false

            if let cancelButton, let cancelReferenceView = keyGridView.topRowKeyView(for: .one),
               cancelLandscapeReferenceView !== cancelReferenceView {
                NSLayoutConstraint.deactivate([
                    cancelButtonLandscapeCenterXConstraint,
                    cancelButtonLandscapeBottomConstraint,
                    cancelButtonLandscapeWidthConstraint,
                    cancelButtonLandscapeHeightConstraint,
                ].compactMap { $0 })

                cancelButtonLandscapeCenterXConstraint = cancelButton.centerXAnchor.constraint(equalTo: cancelReferenceView.centerXAnchor)
                cancelButtonLandscapeBottomConstraint = cancelButton.bottomAnchor.constraint(
                    equalTo: cancelReferenceView.topAnchor,
                    constant: -KeyboardStyle.keyboardRowSpacing
                )
                cancelButtonLandscapeWidthConstraint = cancelButton.widthAnchor.constraint(equalTo: cancelReferenceView.widthAnchor)
                cancelButtonLandscapeHeightConstraint = cancelButton.heightAnchor.constraint(equalTo: cancelReferenceView.heightAnchor)
                cancelLandscapeReferenceView = cancelReferenceView

                NSLayoutConstraint.activate([
                    cancelButtonLandscapeCenterXConstraint!,
                    cancelButtonLandscapeBottomConstraint!,
                    cancelButtonLandscapeWidthConstraint!,
                    cancelButtonLandscapeHeightConstraint!,
                ])
            }

            if let capsLockButton, let capsReferenceView = keyGridView.topRowKeyView(for: .zero),
               capsLandscapeReferenceView !== capsReferenceView {
                NSLayoutConstraint.deactivate([
                    capsLockButtonLandscapeCenterXConstraint,
                    capsLockButtonLandscapeBottomConstraint,
                    capsLockButtonLandscapeWidthConstraint,
                    capsLockButtonLandscapeHeightConstraint,
                ].compactMap { $0 })

                capsLockButtonLandscapeCenterXConstraint = capsLockButton.centerXAnchor.constraint(equalTo: capsReferenceView.centerXAnchor)
                capsLockButtonLandscapeBottomConstraint = capsLockButton.bottomAnchor.constraint(
                    equalTo: capsReferenceView.topAnchor,
                    constant: -KeyboardStyle.keyboardRowSpacing
                )
                capsLockButtonLandscapeWidthConstraint = capsLockButton.widthAnchor.constraint(equalTo: capsReferenceView.widthAnchor)
                capsLockButtonLandscapeHeightConstraint = capsLockButton.heightAnchor.constraint(equalTo: capsReferenceView.heightAnchor)
                capsLandscapeReferenceView = capsReferenceView

                NSLayoutConstraint.activate([
                    capsLockButtonLandscapeCenterXConstraint!,
                    capsLockButtonLandscapeBottomConstraint!,
                    capsLockButtonLandscapeWidthConstraint!,
                    capsLockButtonLandscapeHeightConstraint!,
                ])
            }
        }
    }

    class RowLayout {
        weak var keyGridView: KeyboardKeyGridView?
        weak var rowStack: UIStackView?
        var widthConstraints: [NSLayoutConstraint] = []

        init(keyGridView: KeyboardKeyGridView, rowStack: UIStackView) {
            self.keyGridView = keyGridView
            self.rowStack = rowStack
        }

        func applyLayout(expectedKeyCount: Int, targetWidths: [CGFloat]) {
            guard let rowStack else { return }

            let keyViews = rowStack.arrangedSubviews.compactMap { $0 as? KeyboardKeyView }
            guard keyViews.count == expectedKeyCount else { return }

            rowStack.distribution = .fill

            if widthConstraints.count != targetWidths.count {
                NSLayoutConstraint.deactivate(widthConstraints)
                widthConstraints = zip(keyViews, targetWidths).map { keyView, width in
                    keyView.widthAnchor.constraint(equalToConstant: width)
                }
                NSLayoutConstraint.activate(widthConstraints)
                return
            }

            for (constraint, width) in zip(widthConstraints, targetWidths) {
                constraint.constant = width
            }
        }
    }

    final class ThirdRowLayout: RowLayout {

        func update(isLandscape _: Bool) {
            guard let keyGridView else { return }

            let spacing = KeyboardStyle.keySpacing
            let rowWidth = keyGridView.bounds.width
            let topRowKeyWidth = (rowWidth - (spacing * 9)) / 10
            let specialKeyWidth = (topRowKeyWidth * 1.5) + (spacing * 0.5)
            let middleKeyWidth = (rowWidth - (specialKeyWidth * 2) - (spacing * 6)) / 5

            guard specialKeyWidth > 0, middleKeyWidth > 0 else { return }

            let targetWidths = [
                specialKeyWidth,
                middleKeyWidth,
                middleKeyWidth,
                middleKeyWidth,
                middleKeyWidth,
                middleKeyWidth,
                specialKeyWidth,
            ]

            applyLayout(expectedKeyCount: 7, targetWidths: targetWidths)
        }
    }

    final class BottomRowLayout: RowLayout {
        func update(isLandscape _: Bool) {
            guard let keyGridView else { return }

            let spacing = KeyboardStyle.keySpacing
            let rowWidth = keyGridView.bounds.width
            let topRowKeyWidth = (rowWidth - (spacing * 9)) / 10
            let sideKeyWidth = (topRowKeyWidth * 2.5) + (spacing * 1.5)
            let spaceKeyWidth = rowWidth - (sideKeyWidth * 2) - (spacing * 2)

            guard sideKeyWidth > 0, spaceKeyWidth > 0 else { return }

            let targetWidths = [
                sideKeyWidth,
                spaceKeyWidth,
                sideKeyWidth,
            ]

            applyLayout(expectedKeyCount: 3, targetWidths: targetWidths)
        }
    }
}
