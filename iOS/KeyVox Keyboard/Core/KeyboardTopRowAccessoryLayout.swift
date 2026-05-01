import UIKit

extension KeyboardLayoutGeometry {
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
        private weak var cancelLandscapeReferenceView: UIView?
        private var singleKeyAccessoryStates: [SingleKeyAccessoryID: SingleKeyAccessoryConstraintState] = [:]
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
            let singleKeySlots: [SingleKeyAccessoryID: KeyboardTopRowAccessorySlot]
            let vibesLeading: KeyboardTopRowAccessorySlot?
            let vibesTrailing: KeyboardTopRowAccessorySlot?
            let logoLeading: KeyboardTopRowAccessorySlot
        }

        private enum SingleKeyAccessoryID: CaseIterable {
            case capsLock
            case lists
            case paragraph
            case speak
        }

        private struct SingleKeyAccessory {
            let id: SingleKeyAccessoryID
            weak var button: UIView?
        }

        private final class SingleKeyAccessoryConstraintState {
            var centerXConstraint: NSLayoutConstraint?
            var verticalConstraint: NSLayoutConstraint?
            var widthConstraint: NSLayoutConstraint?
            var heightConstraint: NSLayoutConstraint?
            weak var referenceView: UIView?
            var usesLandscapeHeight = false
            var usesCapsLockHeight = false
            var portraitHeight: CGFloat = 0

            func deactivateConstraints() {
                NSLayoutConstraint.deactivate([
                    centerXConstraint,
                    verticalConstraint,
                    widthConstraint,
                    heightConstraint,
                ].compactMap { $0 })
            }
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
            singleKeyAccessoryStates = Dictionary(
                uniqueKeysWithValues: SingleKeyAccessoryID.allCases.map { ($0, SingleKeyAccessoryConstraintState()) }
            )
        }

        func update(isLandscape: Bool, showsVibesButton: Bool) {
            guard let keyGridView else { return }
            let slotPlan = topRowAccessorySlotPlan(showsVibesButton: showsVibesButton)

            updateSingleKeyAccessories(isLandscape: isLandscape, slotPlan: slotPlan, keyGridView: keyGridView)
            updateVibesButton(isLandscape: isLandscape, showsVibesButton: showsVibesButton, slotPlan: slotPlan, keyGridView: keyGridView)
            updateLogoBar(isLandscape: isLandscape, slotPlan: slotPlan, keyGridView: keyGridView)
            updateCancelButton(isLandscape: isLandscape, keyGridView: keyGridView)
        }

        private func updateSingleKeyAccessories(
            isLandscape: Bool,
            slotPlan: TopRowAccessorySlotPlan,
            keyGridView: KeyboardKeyGridView
        ) {
            for accessory in singleKeyAccessories {
                guard let slot = slotPlan.singleKeySlots[accessory.id],
                      let state = singleKeyAccessoryStates[accessory.id] else {
                    continue
                }

                updateSingleKeyAccessory(
                    accessory.button,
                    state: state,
                    slot: slot,
                    isLandscape: isLandscape,
                    canUseCapsLockHeight: accessory.id != .capsLock,
                    keyGridView: keyGridView
                )
            }
        }

        private func updateSingleKeyAccessory(
            _ button: UIView?,
            state: SingleKeyAccessoryConstraintState,
            slot: KeyboardTopRowAccessorySlot,
            isLandscape: Bool,
            canUseCapsLockHeight: Bool,
            keyGridView: KeyboardKeyGridView
        ) {
            guard let button,
                  let currentReferenceView = keyGridView.topRowKeyView(for: slot) else {
                return
            }

            let usesCapsLockHeight = canUseCapsLockHeight && !isLandscape && capsLockButton != nil
            let resolvedPortraitHeight = min(
                currentReferenceView.bounds.width,
                KeyboardStyle.buttonSize
            )
            let shouldRefreshConstraints =
                state.referenceView !== currentReferenceView
                || state.usesLandscapeHeight != isLandscape
                || state.usesCapsLockHeight != usesCapsLockHeight
                || (
                    isLandscape == false
                    && usesCapsLockHeight == false
                    && abs(state.portraitHeight - resolvedPortraitHeight) > 0.5
                )

            if shouldRefreshConstraints {
                state.deactivateConstraints()

                state.centerXConstraint = button.centerXAnchor.constraint(equalTo: currentReferenceView.centerXAnchor)
                if isLandscape {
                    state.verticalConstraint = button.bottomAnchor.constraint(
                        equalTo: currentReferenceView.topAnchor,
                        constant: -KeyboardStyle.keyboardRowSpacing
                    )
                } else if canUseCapsLockHeight, let capsLockButton {
                    state.verticalConstraint = button.centerYAnchor.constraint(equalTo: capsLockButton.centerYAnchor)
                } else {
                    state.verticalConstraint = button.bottomAnchor.constraint(
                        equalTo: currentReferenceView.topAnchor,
                        constant: -KeyboardStyle.keyboardRowSpacing
                    )
                }
                state.widthConstraint = button.widthAnchor.constraint(equalTo: currentReferenceView.widthAnchor)
                if isLandscape {
                    state.heightConstraint = button.heightAnchor.constraint(equalTo: currentReferenceView.heightAnchor)
                } else if canUseCapsLockHeight, let capsLockButton {
                    state.heightConstraint = button.heightAnchor.constraint(equalTo: capsLockButton.heightAnchor)
                } else {
                    state.heightConstraint = button.heightAnchor.constraint(equalToConstant: resolvedPortraitHeight)
                }
                state.referenceView = currentReferenceView
                state.usesLandscapeHeight = isLandscape
                state.usesCapsLockHeight = usesCapsLockHeight
                state.portraitHeight = resolvedPortraitHeight

                NSLayoutConstraint.activate([
                    state.centerXConstraint!,
                    state.verticalConstraint!,
                    state.widthConstraint!,
                    state.heightConstraint!,
                ])
            }
        }

        private var singleKeyAccessories: [SingleKeyAccessory] {
            [
                SingleKeyAccessory(id: .capsLock, button: capsLockButton),
                SingleKeyAccessory(id: .lists, button: listsButton),
                SingleKeyAccessory(id: .paragraph, button: paragraphButton),
                SingleKeyAccessory(id: .speak, button: speakButton),
            ]
        }

        private func updateVibesButton(
            isLandscape: Bool,
            showsVibesButton: Bool,
            slotPlan: TopRowAccessorySlotPlan,
            keyGridView: KeyboardKeyGridView
        ) {
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
                return
            }

            guard let vibesButton,
                  let vibesLeadingSlot = slotPlan.vibesLeading,
                  let vibesTrailingSlot = slotPlan.vibesTrailing,
                  let currentVibesLeadingReferenceView = keyGridView.topRowKeyView(for: vibesLeadingSlot),
                  let currentVibesTrailingReferenceView = keyGridView.topRowKeyView(for: vibesTrailingSlot) else {
                return
            }

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

        private func updateLogoBar(
            isLandscape: Bool,
            slotPlan: TopRowAccessorySlotPlan,
            keyGridView: KeyboardKeyGridView
        ) {
            guard let logoBarView,
                  let currentLogoLeadingReferenceView = keyGridView.topRowKeyView(for: slotPlan.logoLeading) else {
                return
            }

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

        private func updateCancelButton(isLandscape: Bool, keyGridView: KeyboardKeyGridView) {
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
            var singleKeySlots: [SingleKeyAccessoryID: KeyboardTopRowAccessorySlot] = [:]
            for accessoryID in SingleKeyAccessoryID.allCases {
                singleKeySlots[accessoryID] = takeSlots(width: 1).leading
            }

            return TopRowAccessorySlotPlan(
                singleKeySlots: singleKeySlots,
                vibesLeading: vibesSlots?.leading,
                vibesTrailing: vibesSlots?.trailing,
                logoLeading: .nine
            )
        }
    }
}
