import UIKit

extension KeyboardLayoutGeometry {
    final class TopRowAccessoryLayout {
        private weak var cancelButton: UIView?
        private weak var settingsButton: UIView?
        private weak var capsLockButton: UIView?
        private weak var speakButton: UIView?
        private weak var paragraphButton: UIView?
        private weak var listsButton: UIView?
        private weak var dictionaryButton: UIView?
        private weak var vibesButton: UIView?
        private weak var logoBarView: UIView?
        private weak var keyGridView: KeyboardKeyGridView?
        private let cancelButtonLeadingConstraint: NSLayoutConstraint
        private let settingsButtonLeadingConstraint: NSLayoutConstraint
        private let capsLockButtonTrailingConstraint: NSLayoutConstraint
        private let cancelButtonCenterYConstraint: NSLayoutConstraint
        private let settingsButtonCenterYConstraint: NSLayoutConstraint
        private let capsLockButtonCenterYConstraint: NSLayoutConstraint
        private let cancelButtonWidthConstraint: NSLayoutConstraint
        private let cancelButtonHeightConstraint: NSLayoutConstraint
        private let settingsButtonWidthConstraint: NSLayoutConstraint
        private let settingsButtonHeightConstraint: NSLayoutConstraint
        private let capsLockButtonWidthConstraint: NSLayoutConstraint
        private let capsLockButtonHeightConstraint: NSLayoutConstraint

        private var settingsButtonLandscapeCenterXConstraint: NSLayoutConstraint?
        private var settingsButtonLandscapeBottomConstraint: NSLayoutConstraint?
        private var settingsButtonLandscapeWidthConstraint: NSLayoutConstraint?
        private var settingsButtonLandscapeHeightConstraint: NSLayoutConstraint?
        private var cancelButtonLandscapeCenterXConstraint: NSLayoutConstraint?
        private var cancelButtonLandscapeBottomConstraint: NSLayoutConstraint?
        private var cancelButtonLandscapeWidthConstraint: NSLayoutConstraint?
        private var cancelButtonLandscapeHeightConstraint: NSLayoutConstraint?
        private weak var cancelLandscapeReferenceView: UIView?
        private var cancelUsesLandscapePosition = false
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
            let utilitySlot: KeyboardTopRowAccessorySlot
        }

        private enum SingleKeyAccessoryID: CaseIterable {
            case speak
            case dictionary
            case paragraph
            case lists
            case capsLock
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
            settingsButton: UIView,
            capsLockButton: UIView,
            speakButton: UIView,
            paragraphButton: UIView,
            listsButton: UIView,
            dictionaryButton: UIView,
            vibesButton: UIView,
            logoBarView: UIView,
            keyGridView: KeyboardKeyGridView,
            cancelButtonLeadingConstraint: NSLayoutConstraint,
            settingsButtonLeadingConstraint: NSLayoutConstraint,
            capsLockButtonTrailingConstraint: NSLayoutConstraint,
            cancelButtonCenterYConstraint: NSLayoutConstraint,
            settingsButtonCenterYConstraint: NSLayoutConstraint,
            capsLockButtonCenterYConstraint: NSLayoutConstraint,
            cancelButtonWidthConstraint: NSLayoutConstraint,
            cancelButtonHeightConstraint: NSLayoutConstraint,
            settingsButtonWidthConstraint: NSLayoutConstraint,
            settingsButtonHeightConstraint: NSLayoutConstraint,
            capsLockButtonWidthConstraint: NSLayoutConstraint,
            capsLockButtonHeightConstraint: NSLayoutConstraint
        ) {
            self.cancelButton = cancelButton
            self.settingsButton = settingsButton
            self.capsLockButton = capsLockButton
            self.speakButton = speakButton
            self.paragraphButton = paragraphButton
            self.listsButton = listsButton
            self.dictionaryButton = dictionaryButton
            self.vibesButton = vibesButton
            self.logoBarView = logoBarView
            self.keyGridView = keyGridView
            self.cancelButtonLeadingConstraint = cancelButtonLeadingConstraint
            self.settingsButtonLeadingConstraint = settingsButtonLeadingConstraint
            self.capsLockButtonTrailingConstraint = capsLockButtonTrailingConstraint
            self.cancelButtonCenterYConstraint = cancelButtonCenterYConstraint
            self.settingsButtonCenterYConstraint = settingsButtonCenterYConstraint
            self.capsLockButtonCenterYConstraint = capsLockButtonCenterYConstraint
            self.cancelButtonWidthConstraint = cancelButtonWidthConstraint
            self.cancelButtonHeightConstraint = cancelButtonHeightConstraint
            self.settingsButtonWidthConstraint = settingsButtonWidthConstraint
            self.settingsButtonHeightConstraint = settingsButtonHeightConstraint
            self.capsLockButtonWidthConstraint = capsLockButtonWidthConstraint
            self.capsLockButtonHeightConstraint = capsLockButtonHeightConstraint
            singleKeyAccessoryStates = Dictionary(
                uniqueKeysWithValues: SingleKeyAccessoryID.allCases.map { ($0, SingleKeyAccessoryConstraintState()) }
            )
        }

        func update(
            isLandscape: Bool,
            showsVibesButton: Bool,
            isLeftHandedLayoutEnabled: Bool
        ) {
            guard let keyGridView else { return }
            let slotPlan = topRowAccessorySlotPlan(
                showsVibesButton: showsVibesButton,
                isLeftHandedLayoutEnabled: isLeftHandedLayoutEnabled
            )

            updateSingleKeyAccessories(isLandscape: isLandscape, slotPlan: slotPlan, keyGridView: keyGridView)
            updateVibesButton(isLandscape: isLandscape, showsVibesButton: showsVibesButton, slotPlan: slotPlan, keyGridView: keyGridView)
            updateLogoBar(isLandscape: isLandscape, slotPlan: slotPlan, keyGridView: keyGridView)
            updateCancelButton(isLandscape: isLandscape, slotPlan: slotPlan, keyGridView: keyGridView)
        }

        func placeholderSlots(
            showsVibesButton: Bool,
            isLeftHandedLayoutEnabled: Bool
        ) -> (leading: KeyboardTopRowAccessorySlot, trailing: KeyboardTopRowAccessorySlot) {
            let slotPlan = topRowAccessorySlotPlan(
                showsVibesButton: showsVibesButton,
                isLeftHandedLayoutEnabled: isLeftHandedLayoutEnabled
            )
            return (slotPlan.logoLeading, slotPlan.utilitySlot)
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
                SingleKeyAccessory(id: .speak, button: speakButton),
                SingleKeyAccessory(id: .dictionary, button: dictionaryButton),
                SingleKeyAccessory(id: .paragraph, button: paragraphButton),
                SingleKeyAccessory(id: .lists, button: listsButton),
                SingleKeyAccessory(id: .capsLock, button: capsLockButton),
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
                } else if let vibesButton {
                    logoBarVerticalConstraint = logoBarView.bottomAnchor.constraint(
                        equalTo: vibesButton.bottomAnchor
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

        private func updateCancelButton(
            isLandscape: Bool,
            slotPlan: TopRowAccessorySlotPlan,
            keyGridView: KeyboardKeyGridView
        ) {
            settingsButtonLeadingConstraint.isActive = false
            settingsButtonCenterYConstraint.isActive = false
            settingsButtonWidthConstraint.isActive = false
            settingsButtonHeightConstraint.isActive = false
            cancelButtonLeadingConstraint.isActive = false
            cancelButtonCenterYConstraint.isActive = false
            cancelButtonWidthConstraint.isActive = false
            cancelButtonHeightConstraint.isActive = false
            capsLockButtonTrailingConstraint.isActive = false
            capsLockButtonCenterYConstraint.isActive = false
            capsLockButtonWidthConstraint.isActive = false
            capsLockButtonHeightConstraint.isActive = false

            guard let cancelReferenceView = keyGridView.topRowKeyView(for: slotPlan.utilitySlot) else {
                NSLayoutConstraint.deactivate([
                    settingsButtonLandscapeCenterXConstraint,
                    settingsButtonLandscapeBottomConstraint,
                    settingsButtonLandscapeWidthConstraint,
                    settingsButtonLandscapeHeightConstraint,
                    cancelButtonLandscapeCenterXConstraint,
                    cancelButtonLandscapeBottomConstraint,
                    cancelButtonLandscapeWidthConstraint,
                    cancelButtonLandscapeHeightConstraint,
                ].compactMap { $0 })

                settingsButtonLandscapeCenterXConstraint = nil
                settingsButtonLandscapeBottomConstraint = nil
                settingsButtonLandscapeWidthConstraint = nil
                settingsButtonLandscapeHeightConstraint = nil
                cancelButtonLandscapeCenterXConstraint = nil
                cancelButtonLandscapeBottomConstraint = nil
                cancelButtonLandscapeWidthConstraint = nil
                cancelButtonLandscapeHeightConstraint = nil
                cancelLandscapeReferenceView = nil
                cancelUsesLandscapePosition = false
                capsLockButtonHeightConstraint.isActive = false
                return
            }

            if cancelLandscapeReferenceView !== cancelReferenceView || cancelUsesLandscapePosition != isLandscape {
                NSLayoutConstraint.deactivate([
                    settingsButtonLandscapeCenterXConstraint,
                    settingsButtonLandscapeBottomConstraint,
                    settingsButtonLandscapeWidthConstraint,
                    settingsButtonLandscapeHeightConstraint,
                    cancelButtonLandscapeCenterXConstraint,
                    cancelButtonLandscapeBottomConstraint,
                    cancelButtonLandscapeWidthConstraint,
                    cancelButtonLandscapeHeightConstraint,
                ].compactMap { $0 })

                if let settingsButton {
                    settingsButtonLandscapeCenterXConstraint = settingsButton.centerXAnchor.constraint(equalTo: cancelReferenceView.centerXAnchor)
                    if isLandscape {
                        settingsButtonLandscapeBottomConstraint = settingsButton.bottomAnchor.constraint(
                            equalTo: cancelReferenceView.topAnchor,
                            constant: -KeyboardStyle.keyboardRowSpacing
                        )
                    } else if let capsLockButton {
                        settingsButtonLandscapeBottomConstraint = settingsButton.centerYAnchor.constraint(equalTo: capsLockButton.centerYAnchor)
                    } else {
                        settingsButtonLandscapeBottomConstraint = settingsButton.bottomAnchor.constraint(
                            equalTo: cancelReferenceView.topAnchor,
                            constant: -KeyboardStyle.keyboardRowSpacing
                        )
                    }
                    settingsButtonLandscapeWidthConstraint = settingsButton.widthAnchor.constraint(equalTo: cancelReferenceView.widthAnchor)
                    if isLandscape {
                        settingsButtonLandscapeHeightConstraint = settingsButton.heightAnchor.constraint(equalTo: cancelReferenceView.heightAnchor)
                    } else if let capsLockButton {
                        settingsButtonLandscapeHeightConstraint = settingsButton.heightAnchor.constraint(equalTo: capsLockButton.heightAnchor)
                    } else {
                        settingsButtonLandscapeHeightConstraint = settingsButton.heightAnchor.constraint(equalToConstant: min(cancelReferenceView.bounds.width, KeyboardStyle.buttonSize))
                    }
                }
                if let cancelButton {
                    cancelButtonLandscapeCenterXConstraint = cancelButton.centerXAnchor.constraint(equalTo: cancelReferenceView.centerXAnchor)
                    if isLandscape {
                        cancelButtonLandscapeBottomConstraint = cancelButton.bottomAnchor.constraint(
                            equalTo: cancelReferenceView.topAnchor,
                            constant: -KeyboardStyle.keyboardRowSpacing
                        )
                    } else if let capsLockButton {
                        cancelButtonLandscapeBottomConstraint = cancelButton.centerYAnchor.constraint(equalTo: capsLockButton.centerYAnchor)
                    } else {
                        cancelButtonLandscapeBottomConstraint = cancelButton.bottomAnchor.constraint(
                            equalTo: cancelReferenceView.topAnchor,
                            constant: -KeyboardStyle.keyboardRowSpacing
                        )
                    }
                    cancelButtonLandscapeWidthConstraint = cancelButton.widthAnchor.constraint(equalTo: cancelReferenceView.widthAnchor)
                    if isLandscape {
                        cancelButtonLandscapeHeightConstraint = cancelButton.heightAnchor.constraint(equalTo: cancelReferenceView.heightAnchor)
                    } else if let capsLockButton {
                        cancelButtonLandscapeHeightConstraint = cancelButton.heightAnchor.constraint(equalTo: capsLockButton.heightAnchor)
                    } else {
                        cancelButtonLandscapeHeightConstraint = cancelButton.heightAnchor.constraint(equalToConstant: min(cancelReferenceView.bounds.width, KeyboardStyle.buttonSize))
                    }
                }
                cancelLandscapeReferenceView = cancelReferenceView
                cancelUsesLandscapePosition = isLandscape

                NSLayoutConstraint.activate([
                    settingsButtonLandscapeCenterXConstraint,
                    settingsButtonLandscapeBottomConstraint,
                    settingsButtonLandscapeWidthConstraint,
                    settingsButtonLandscapeHeightConstraint,
                    cancelButtonLandscapeCenterXConstraint!,
                    cancelButtonLandscapeBottomConstraint!,
                    cancelButtonLandscapeWidthConstraint!,
                    cancelButtonLandscapeHeightConstraint!,
                ].compactMap { $0 })
            }
        }

        private func topRowAccessorySlotPlan(
            showsVibesButton: Bool,
            isLeftHandedLayoutEnabled: Bool
        ) -> TopRowAccessorySlotPlan {
            var singleKeySlots: [SingleKeyAccessoryID: KeyboardTopRowAccessorySlot] = [:]
            let vibesSlots: (leading: KeyboardTopRowAccessorySlot, trailing: KeyboardTopRowAccessorySlot)?

            if isLeftHandedLayoutEnabled, showsVibesButton {
                singleKeySlots[.speak] = .nine
                singleKeySlots[.capsLock] = .eight
                singleKeySlots[.paragraph] = .seven
                singleKeySlots[.lists] = .six
                singleKeySlots[.dictionary] = .five
                vibesSlots = (.three, .four)
            } else if isLeftHandedLayoutEnabled {
                singleKeySlots[.speak] = .seven
                singleKeySlots[.capsLock] = .six
                singleKeySlots[.paragraph] = .five
                singleKeySlots[.lists] = .four
                singleKeySlots[.dictionary] = .three
                vibesSlots = nil
            } else if showsVibesButton {
                singleKeySlots[.speak] = .two
                singleKeySlots[.capsLock] = .three
                singleKeySlots[.paragraph] = .four
                singleKeySlots[.lists] = .five
                singleKeySlots[.dictionary] = .six
                vibesSlots = (.seven, .eight)
            } else {
                singleKeySlots[.speak] = .four
                singleKeySlots[.capsLock] = .five
                singleKeySlots[.paragraph] = .six
                singleKeySlots[.lists] = .seven
                singleKeySlots[.dictionary] = .eight
                vibesSlots = nil
            }

            return TopRowAccessorySlotPlan(
                singleKeySlots: singleKeySlots,
                vibesLeading: vibesSlots?.leading,
                vibesTrailing: vibesSlots?.trailing,
                logoLeading: isLeftHandedLayoutEnabled ? .one : .nine,
                utilitySlot: isLeftHandedLayoutEnabled ? .zero : .one
            )
        }
    }
}
