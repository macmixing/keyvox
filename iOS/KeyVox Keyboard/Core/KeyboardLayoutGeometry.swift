
import UIKit

enum KeyboardLayoutGeometry {
    final class TopRowAccessoryLayout {
        private weak var cancelButton: UIView?
        private weak var capsLockButton: UIView?
        private weak var speakButton: UIView?
        private weak var paragraphButton: UIView?
        private weak var listsButton: UIView?
        private weak var vibesButton: UIView?
        private weak var logoBarView: UIView?
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
        private var capsLockButtonUsesLandscapeHeight = false
        private var capsLockButtonPortraitHeight: CGFloat = 0
        private var speakButtonCenterXConstraint: NSLayoutConstraint?
        private var speakButtonVerticalConstraint: NSLayoutConstraint?
        private var speakButtonWidthConstraint: NSLayoutConstraint?
        private var speakButtonHeightConstraint: NSLayoutConstraint?
        private weak var speakReferenceView: UIView?
        private var speakButtonUsesLandscapeHeight = false
        private var speakButtonUsesCapsLockHeight = false
        private var speakButtonPortraitHeight: CGFloat = 0
        private var paragraphButtonCenterXConstraint: NSLayoutConstraint?
        private var paragraphButtonVerticalConstraint: NSLayoutConstraint?
        private var paragraphButtonWidthConstraint: NSLayoutConstraint?
        private var paragraphButtonHeightConstraint: NSLayoutConstraint?
        private weak var paragraphReferenceView: UIView?
        private var paragraphButtonUsesLandscapeHeight = false
        private var paragraphButtonUsesCapsLockHeight = false
        private var paragraphButtonPortraitHeight: CGFloat = 0
        private var listsButtonCenterXConstraint: NSLayoutConstraint?
        private var listsButtonVerticalConstraint: NSLayoutConstraint?
        private var listsButtonWidthConstraint: NSLayoutConstraint?
        private var listsButtonHeightConstraint: NSLayoutConstraint?
        private weak var listsReferenceView: UIView?
        private var listsButtonUsesLandscapeHeight = false
        private var listsButtonUsesCapsLockHeight = false
        private var listsButtonPortraitHeight: CGFloat = 0
        private var vibesButtonLeadingConstraint: NSLayoutConstraint?
        private var vibesButtonTrailingConstraint: NSLayoutConstraint?
        private var vibesButtonVerticalConstraint: NSLayoutConstraint?
        private var vibesButtonHeightConstraint: NSLayoutConstraint?
        private weak var vibesLeadingReferenceView: UIView?
        private weak var vibesTrailingReferenceView: UIView?
        private var vibesButtonUsesLandscapeHeight = false
        private var vibesButtonUsesCapsLockHeight = false
        private var vibesButtonPortraitHeight: CGFloat = 0
        private var logoBarCenterXConstraint: NSLayoutConstraint?
        private var logoBarVerticalConstraint: NSLayoutConstraint?
        private weak var logoLeadingReferenceView: UIView?
        private var logoBarUsesLandscapeVerticalPosition = false
        private var logoBarUsesCapsLockVerticalPosition = false

        private struct TopRowAccessorySlotPlan {
            let speak: KeyboardTopRowAccessorySlot
            let paragraph: KeyboardTopRowAccessorySlot
            let lists: KeyboardTopRowAccessorySlot
            let capsLock: KeyboardTopRowAccessorySlot
            let vibesLeading: KeyboardTopRowAccessorySlot?
            let vibesTrailing: KeyboardTopRowAccessorySlot?
            let logoLeading: KeyboardTopRowAccessorySlot
        }

        init(
            cancelButton: UIView,
            capsLockButton: UIView,
            speakButton: UIView,
            paragraphButton: UIView,
            listsButton: UIView,
            vibesButton: UIView,
            logoBarView: UIView,
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
            self.paragraphButton = paragraphButton
            self.listsButton = listsButton
            self.vibesButton = vibesButton
            self.logoBarView = logoBarView
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

        func update(isLandscape: Bool, showsVibesButton: Bool) {
            guard let keyGridView else { return }
            let slotPlan = topRowAccessorySlotPlan(showsVibesButton: showsVibesButton)

            if let capsLockButton,
               let currentCapsReferenceView = keyGridView.topRowKeyView(for: slotPlan.capsLock) {
                let resolvedCapsLockButtonPortraitHeight = min(
                    currentCapsReferenceView.bounds.width,
                    KeyboardStyle.buttonSize
                )
                let shouldRefreshCapsConstraints =
                    capsLandscapeReferenceView !== currentCapsReferenceView
                    || capsLockButtonUsesLandscapeHeight != isLandscape
                    || (
                        isLandscape == false
                        && abs(capsLockButtonPortraitHeight - resolvedCapsLockButtonPortraitHeight) > 0.5
                    )

                if shouldRefreshCapsConstraints {
                    NSLayoutConstraint.deactivate([
                        capsLockButtonLandscapeCenterXConstraint,
                        capsLockButtonLandscapeBottomConstraint,
                        capsLockButtonLandscapeWidthConstraint,
                        capsLockButtonLandscapeHeightConstraint,
                    ].compactMap { $0 })

                    capsLockButtonLandscapeCenterXConstraint = capsLockButton.centerXAnchor.constraint(equalTo: currentCapsReferenceView.centerXAnchor)
                    capsLockButtonLandscapeBottomConstraint = capsLockButton.bottomAnchor.constraint(
                        equalTo: currentCapsReferenceView.topAnchor,
                        constant: -KeyboardStyle.keyboardRowSpacing
                    )
                    capsLockButtonLandscapeWidthConstraint = capsLockButton.widthAnchor.constraint(equalTo: currentCapsReferenceView.widthAnchor)
                    if isLandscape {
                        capsLockButtonLandscapeHeightConstraint = capsLockButton.heightAnchor.constraint(equalTo: currentCapsReferenceView.heightAnchor)
                    } else {
                        capsLockButtonLandscapeHeightConstraint = capsLockButton.heightAnchor.constraint(equalToConstant: resolvedCapsLockButtonPortraitHeight)
                    }
                    capsLandscapeReferenceView = currentCapsReferenceView
                    capsLockButtonUsesLandscapeHeight = isLandscape
                    capsLockButtonPortraitHeight = resolvedCapsLockButtonPortraitHeight

                    NSLayoutConstraint.activate([
                        capsLockButtonLandscapeCenterXConstraint!,
                        capsLockButtonLandscapeBottomConstraint!,
                        capsLockButtonLandscapeWidthConstraint!,
                        capsLockButtonLandscapeHeightConstraint!,
                    ])
                }
            }

            if let speakButton,
               let currentSpeakReferenceView = keyGridView.topRowKeyView(for: slotPlan.speak) {
                let usesCapsLockHeight = !isLandscape && capsLockButton != nil
                let resolvedSpeakButtonPortraitHeight = min(
                    currentSpeakReferenceView.bounds.width,
                    KeyboardStyle.buttonSize
                )
                let shouldRefreshSpeakConstraints =
                    speakReferenceView !== currentSpeakReferenceView
                    || speakButtonUsesLandscapeHeight != isLandscape
                    || speakButtonUsesCapsLockHeight != usesCapsLockHeight
                    || (
                        isLandscape == false
                        && usesCapsLockHeight == false
                        && abs(speakButtonPortraitHeight - resolvedSpeakButtonPortraitHeight) > 0.5
                    )

                if shouldRefreshSpeakConstraints {
                    NSLayoutConstraint.deactivate([
                        speakButtonCenterXConstraint,
                        speakButtonVerticalConstraint,
                        speakButtonWidthConstraint,
                        speakButtonHeightConstraint,
                    ].compactMap { $0 })

                    speakButtonCenterXConstraint = speakButton.centerXAnchor.constraint(equalTo: currentSpeakReferenceView.centerXAnchor)
                    if isLandscape {
                        speakButtonVerticalConstraint = speakButton.bottomAnchor.constraint(
                            equalTo: currentSpeakReferenceView.topAnchor,
                            constant: -KeyboardStyle.keyboardRowSpacing
                        )
                    } else if let capsLockButton {
                        speakButtonVerticalConstraint = speakButton.centerYAnchor.constraint(equalTo: capsLockButton.centerYAnchor)
                    } else {
                        speakButtonVerticalConstraint = speakButton.bottomAnchor.constraint(
                            equalTo: currentSpeakReferenceView.topAnchor,
                            constant: -KeyboardStyle.keyboardRowSpacing
                        )
                    }
                    speakButtonWidthConstraint = speakButton.widthAnchor.constraint(equalTo: currentSpeakReferenceView.widthAnchor)
                    if isLandscape {
                        speakButtonHeightConstraint = speakButton.heightAnchor.constraint(equalTo: currentSpeakReferenceView.heightAnchor)
                    } else if let capsLockButton {
                        speakButtonHeightConstraint = speakButton.heightAnchor.constraint(equalTo: capsLockButton.heightAnchor)
                    } else {
                        speakButtonHeightConstraint = speakButton.heightAnchor.constraint(equalToConstant: resolvedSpeakButtonPortraitHeight)
                    }
                    speakReferenceView = currentSpeakReferenceView
                    speakButtonUsesLandscapeHeight = isLandscape
                    speakButtonUsesCapsLockHeight = usesCapsLockHeight
                    speakButtonPortraitHeight = resolvedSpeakButtonPortraitHeight

                    NSLayoutConstraint.activate([
                        speakButtonCenterXConstraint!,
                        speakButtonVerticalConstraint!,
                        speakButtonWidthConstraint!,
                        speakButtonHeightConstraint!,
                    ])
                }
            }

            if let paragraphButton,
               let currentParagraphReferenceView = keyGridView.topRowKeyView(for: slotPlan.paragraph) {
                let usesCapsLockHeight = !isLandscape && capsLockButton != nil
                let resolvedParagraphButtonPortraitHeight = min(
                    currentParagraphReferenceView.bounds.width,
                    KeyboardStyle.buttonSize
                )
                let shouldRefreshParagraphConstraints =
                    paragraphReferenceView !== currentParagraphReferenceView
                    || paragraphButtonUsesLandscapeHeight != isLandscape
                    || paragraphButtonUsesCapsLockHeight != usesCapsLockHeight
                    || (
                        isLandscape == false
                        && usesCapsLockHeight == false
                        && abs(paragraphButtonPortraitHeight - resolvedParagraphButtonPortraitHeight) > 0.5
                    )

                if shouldRefreshParagraphConstraints {
                    NSLayoutConstraint.deactivate([
                        paragraphButtonCenterXConstraint,
                        paragraphButtonVerticalConstraint,
                        paragraphButtonWidthConstraint,
                        paragraphButtonHeightConstraint,
                    ].compactMap { $0 })

                    paragraphButtonCenterXConstraint = paragraphButton.centerXAnchor.constraint(equalTo: currentParagraphReferenceView.centerXAnchor)
                    if isLandscape {
                        paragraphButtonVerticalConstraint = paragraphButton.bottomAnchor.constraint(
                            equalTo: currentParagraphReferenceView.topAnchor,
                            constant: -KeyboardStyle.keyboardRowSpacing
                        )
                    } else if let capsLockButton {
                        paragraphButtonVerticalConstraint = paragraphButton.centerYAnchor.constraint(equalTo: capsLockButton.centerYAnchor)
                    } else {
                        paragraphButtonVerticalConstraint = paragraphButton.bottomAnchor.constraint(
                            equalTo: currentParagraphReferenceView.topAnchor,
                            constant: -KeyboardStyle.keyboardRowSpacing
                        )
                    }
                    paragraphButtonWidthConstraint = paragraphButton.widthAnchor.constraint(equalTo: currentParagraphReferenceView.widthAnchor)
                    if isLandscape {
                        paragraphButtonHeightConstraint = paragraphButton.heightAnchor.constraint(equalTo: currentParagraphReferenceView.heightAnchor)
                    } else if let capsLockButton {
                        paragraphButtonHeightConstraint = paragraphButton.heightAnchor.constraint(equalTo: capsLockButton.heightAnchor)
                    } else {
                        paragraphButtonHeightConstraint = paragraphButton.heightAnchor.constraint(equalToConstant: resolvedParagraphButtonPortraitHeight)
                    }
                    paragraphReferenceView = currentParagraphReferenceView
                    paragraphButtonUsesLandscapeHeight = isLandscape
                    paragraphButtonUsesCapsLockHeight = usesCapsLockHeight
                    paragraphButtonPortraitHeight = resolvedParagraphButtonPortraitHeight

                    NSLayoutConstraint.activate([
                        paragraphButtonCenterXConstraint!,
                        paragraphButtonVerticalConstraint!,
                        paragraphButtonWidthConstraint!,
                        paragraphButtonHeightConstraint!,
                    ])
                }
            }

            if let listsButton,
               let currentListsReferenceView = keyGridView.topRowKeyView(for: slotPlan.lists) {
                let usesCapsLockHeight = !isLandscape && capsLockButton != nil
                let resolvedListsButtonPortraitHeight = min(
                    currentListsReferenceView.bounds.width,
                    KeyboardStyle.buttonSize
                )
                let shouldRefreshListsConstraints =
                    listsReferenceView !== currentListsReferenceView
                    || listsButtonUsesLandscapeHeight != isLandscape
                    || listsButtonUsesCapsLockHeight != usesCapsLockHeight
                    || (
                        isLandscape == false
                        && usesCapsLockHeight == false
                        && abs(listsButtonPortraitHeight - resolvedListsButtonPortraitHeight) > 0.5
                    )

                if shouldRefreshListsConstraints {
                    NSLayoutConstraint.deactivate([
                        listsButtonCenterXConstraint,
                        listsButtonVerticalConstraint,
                        listsButtonWidthConstraint,
                        listsButtonHeightConstraint,
                    ].compactMap { $0 })

                    listsButtonCenterXConstraint = listsButton.centerXAnchor.constraint(equalTo: currentListsReferenceView.centerXAnchor)
                    if isLandscape {
                        listsButtonVerticalConstraint = listsButton.bottomAnchor.constraint(
                            equalTo: currentListsReferenceView.topAnchor,
                            constant: -KeyboardStyle.keyboardRowSpacing
                        )
                    } else if let capsLockButton {
                        listsButtonVerticalConstraint = listsButton.centerYAnchor.constraint(equalTo: capsLockButton.centerYAnchor)
                    } else {
                        listsButtonVerticalConstraint = listsButton.bottomAnchor.constraint(
                            equalTo: currentListsReferenceView.topAnchor,
                            constant: -KeyboardStyle.keyboardRowSpacing
                        )
                    }
                    listsButtonWidthConstraint = listsButton.widthAnchor.constraint(equalTo: currentListsReferenceView.widthAnchor)
                    if isLandscape {
                        listsButtonHeightConstraint = listsButton.heightAnchor.constraint(equalTo: currentListsReferenceView.heightAnchor)
                    } else if let capsLockButton {
                        listsButtonHeightConstraint = listsButton.heightAnchor.constraint(equalTo: capsLockButton.heightAnchor)
                    } else {
                        listsButtonHeightConstraint = listsButton.heightAnchor.constraint(equalToConstant: resolvedListsButtonPortraitHeight)
                    }
                    listsReferenceView = currentListsReferenceView
                    listsButtonUsesLandscapeHeight = isLandscape
                    listsButtonUsesCapsLockHeight = usesCapsLockHeight
                    listsButtonPortraitHeight = resolvedListsButtonPortraitHeight

                    NSLayoutConstraint.activate([
                        listsButtonCenterXConstraint!,
                        listsButtonVerticalConstraint!,
                        listsButtonWidthConstraint!,
                        listsButtonHeightConstraint!,
                    ])
                }
            }

            if showsVibesButton == false {
                NSLayoutConstraint.deactivate([
                    vibesButtonLeadingConstraint,
                    vibesButtonTrailingConstraint,
                    vibesButtonVerticalConstraint,
                    vibesButtonHeightConstraint,
                ].compactMap { $0 })
                vibesButtonLeadingConstraint = nil
                vibesButtonTrailingConstraint = nil
                vibesButtonVerticalConstraint = nil
                vibesButtonHeightConstraint = nil
                vibesLeadingReferenceView = nil
                vibesTrailingReferenceView = nil
            }

            if showsVibesButton,
               let vibesButton,
               let vibesLeadingSlot = slotPlan.vibesLeading,
               let vibesTrailingSlot = slotPlan.vibesTrailing,
               let currentVibesLeadingReferenceView = keyGridView.topRowKeyView(for: vibesLeadingSlot),
               let currentVibesTrailingReferenceView = keyGridView.topRowKeyView(for: vibesTrailingSlot) {
                let usesCapsLockHeight = !isLandscape && capsLockButton != nil
                let resolvedVibesButtonPortraitHeight = min(
                    currentVibesLeadingReferenceView.bounds.width,
                    KeyboardStyle.buttonSize
                )
                let shouldRefreshVibesConstraints =
                    vibesLeadingReferenceView !== currentVibesLeadingReferenceView
                    || vibesTrailingReferenceView !== currentVibesTrailingReferenceView
                    || vibesButtonUsesLandscapeHeight != isLandscape
                    || vibesButtonUsesCapsLockHeight != usesCapsLockHeight
                    || (
                        isLandscape == false
                        && usesCapsLockHeight == false
                        && abs(vibesButtonPortraitHeight - resolvedVibesButtonPortraitHeight) > 0.5
                    )

                if shouldRefreshVibesConstraints {
                    NSLayoutConstraint.deactivate([
                        vibesButtonLeadingConstraint,
                        vibesButtonTrailingConstraint,
                        vibesButtonVerticalConstraint,
                        vibesButtonHeightConstraint,
                    ].compactMap { $0 })

                    vibesButtonLeadingConstraint = vibesButton.leadingAnchor.constraint(equalTo: currentVibesLeadingReferenceView.leadingAnchor)
                    vibesButtonTrailingConstraint = vibesButton.trailingAnchor.constraint(equalTo: currentVibesTrailingReferenceView.trailingAnchor)
                    if isLandscape {
                        vibesButtonVerticalConstraint = vibesButton.bottomAnchor.constraint(
                            equalTo: currentVibesLeadingReferenceView.topAnchor,
                            constant: -KeyboardStyle.keyboardRowSpacing
                        )
                    } else if let capsLockButton {
                        vibesButtonVerticalConstraint = vibesButton.centerYAnchor.constraint(equalTo: capsLockButton.centerYAnchor)
                    } else {
                        vibesButtonVerticalConstraint = vibesButton.bottomAnchor.constraint(
                            equalTo: currentVibesLeadingReferenceView.topAnchor,
                            constant: -KeyboardStyle.keyboardRowSpacing
                        )
                    }
                    if isLandscape {
                        vibesButtonHeightConstraint = vibesButton.heightAnchor.constraint(equalTo: currentVibesLeadingReferenceView.heightAnchor)
                    } else if let capsLockButton {
                        vibesButtonHeightConstraint = vibesButton.heightAnchor.constraint(equalTo: capsLockButton.heightAnchor)
                    } else {
                        vibesButtonHeightConstraint = vibesButton.heightAnchor.constraint(equalToConstant: resolvedVibesButtonPortraitHeight)
                    }
                    vibesLeadingReferenceView = currentVibesLeadingReferenceView
                    vibesTrailingReferenceView = currentVibesTrailingReferenceView
                    vibesButtonUsesLandscapeHeight = isLandscape
                    vibesButtonUsesCapsLockHeight = usesCapsLockHeight
                    vibesButtonPortraitHeight = resolvedVibesButtonPortraitHeight

                    NSLayoutConstraint.activate([
                        vibesButtonLeadingConstraint!,
                        vibesButtonTrailingConstraint!,
                        vibesButtonVerticalConstraint!,
                        vibesButtonHeightConstraint!,
                    ])
                }
            }

            if let logoBarView,
               let currentLogoLeadingReferenceView = keyGridView.topRowKeyView(for: slotPlan.logoLeading) {
                (logoBarView as? KeyboardLogoBarView)?.applyToolbarDiameter(
                    isLandscape
                        ? KeyboardLogoBarView.landscapeToolbarDiameter
                        : KeyboardLogoBarView.toolbarDiameter
                )
                let usesCapsLockVerticalPosition = !isLandscape && capsLockButton != nil
                let shouldRefreshLogoConstraints =
                    logoLeadingReferenceView !== currentLogoLeadingReferenceView
                    || logoBarUsesLandscapeVerticalPosition != isLandscape
                    || logoBarUsesCapsLockVerticalPosition != usesCapsLockVerticalPosition

                if shouldRefreshLogoConstraints {
                    NSLayoutConstraint.deactivate([
                        logoBarCenterXConstraint,
                        logoBarVerticalConstraint,
                    ].compactMap { $0 })

                    logoBarCenterXConstraint = logoBarView.centerXAnchor.constraint(
                        equalTo: currentLogoLeadingReferenceView.trailingAnchor,
                        constant: KeyboardStyle.keySpacing / 2
                    )
                    if isLandscape {
                        logoBarVerticalConstraint = logoBarView.bottomAnchor.constraint(
                            equalTo: currentLogoLeadingReferenceView.topAnchor,
                            constant: -KeyboardStyle.keyboardRowSpacing
                        )
                    } else if let capsLockButton {
                        logoBarVerticalConstraint = logoBarView.centerYAnchor.constraint(
                            equalTo: capsLockButton.centerYAnchor,
                            constant: -10
                        )
                    } else {
                        logoBarVerticalConstraint = logoBarView.bottomAnchor.constraint(
                            equalTo: currentLogoLeadingReferenceView.topAnchor,
                            constant: -(KeyboardStyle.keyboardRowSpacing + 10)
                        )
                    }
                    logoLeadingReferenceView = currentLogoLeadingReferenceView
                    logoBarUsesLandscapeVerticalPosition = isLandscape
                    logoBarUsesCapsLockVerticalPosition = usesCapsLockVerticalPosition

                    NSLayoutConstraint.activate([
                        logoBarCenterXConstraint!,
                        logoBarVerticalConstraint!,
                    ])
                }
            }

            if !isLandscape {
                NSLayoutConstraint.deactivate([
                    cancelButtonLandscapeCenterXConstraint,
                    cancelButtonLandscapeBottomConstraint,
                    cancelButtonLandscapeWidthConstraint,
                    cancelButtonLandscapeHeightConstraint,
                ].compactMap { $0 })

                cancelButtonLandscapeCenterXConstraint = nil
                cancelButtonLandscapeBottomConstraint = nil
                cancelButtonLandscapeWidthConstraint = nil
                cancelButtonLandscapeHeightConstraint = nil
                cancelLandscapeReferenceView = nil

                cancelButtonLeadingConstraint.isActive = true
                cancelButtonCenterYConstraint.isActive = true
                cancelButtonWidthConstraint.isActive = true
                cancelButtonHeightConstraint.isActive = true
                capsLockButtonTrailingConstraint.isActive = false
                capsLockButtonCenterYConstraint.isActive = false
                capsLockButtonWidthConstraint.isActive = false
                capsLockButtonHeightConstraint.isActive = false
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

        }

        private func topRowAccessorySlotPlan(showsVibesButton: Bool) -> TopRowAccessorySlotPlan {
            var nextTrailingRawValue = KeyboardTopRowAccessorySlot.eight.rawValue

            func takeSlots(width: Int) -> (leading: KeyboardTopRowAccessorySlot, trailing: KeyboardTopRowAccessorySlot) {
                let leadingRawValue = nextTrailingRawValue - width + 1
                let leading = KeyboardTopRowAccessorySlot(rawValue: leadingRawValue) ?? .three
                let trailing = KeyboardTopRowAccessorySlot(rawValue: nextTrailingRawValue) ?? .eight
                nextTrailingRawValue = leadingRawValue - 1
                return (leading, trailing)
            }

            let vibesSlots = showsVibesButton ? takeSlots(width: 2) : nil
            let capsLockSlot = takeSlots(width: 1).leading
            let listsSlot = takeSlots(width: 1).leading
            let paragraphSlot = takeSlots(width: 1).leading
            let speakSlot = takeSlots(width: 1).leading

            return TopRowAccessorySlotPlan(
                speak: speakSlot,
                paragraph: paragraphSlot,
                lists: listsSlot,
                capsLock: capsLockSlot,
                vibesLeading: vibesSlots?.leading,
                vibesTrailing: vibesSlots?.trailing,
                logoLeading: .nine
            )
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
