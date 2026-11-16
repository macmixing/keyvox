import CoreGraphics

enum KeyboardKeysMode: Equatable {
    case full
    case compact

    static func resolve(isCompactKeysEnabled: Bool, isCompactKeysActive: Bool) -> KeyboardKeysMode {
        isCompactKeysEnabled && isCompactKeysActive ? .compact : .full
    }

    /// The keyboard's height: the portrait height, changed by however much shorter or taller the
    /// keys are in landscape or on iPad, and shorter by the toolbar's row on a page without it.
    /// Under Display Zoom every part of it shrinks by the zoom.
    func keyboardHeight(
        isLandscape: Bool,
        display: KeyboardDisplay = .standard,
        zoom: KeyboardDisplayZoom = .none,
        showsToolbar: Bool = true
    ) -> CGFloat {
        let portraitHeight: CGFloat
        switch self {
        case .full:
            portraitHeight = KeyboardStyle.fullKeyboardHeight
        case .compact:
            portraitHeight = KeyboardStyle.compactKeyboardHeight
        }
        let heightAroundKeys = portraitHeight - keyGridHeight(isLandscape: false)
            - (showsToolbar ? 0 : KeyboardStyle.toolbarRowHeight)
        return heightAroundKeys * zoom.sizeScale
            + keyGridHeight(isLandscape: isLandscape, display: display, zoom: zoom)
    }

    /// Keys are shorter in landscape, in both full and Compact Keys, though less so on an open
    /// foldable's inner display. On iPad they're taller than on iPhone in both orientations. Under
    /// Display Zoom they shrink by the zoom.
    func keyHeight(
        isLandscape: Bool,
        display: KeyboardDisplay = .standard,
        zoom: KeyboardDisplayZoom = .none
    ) -> CGFloat {
        let height: CGFloat
        switch display {
        case .pad:
            height = isLandscape ? KeyboardStyle.padLandscapeKeyHeight : KeyboardStyle.padKeyHeight
        case .openFoldable:
            height = isLandscape ? KeyboardStyle.openFoldableLandscapeKeyHeight : KeyboardStyle.keyHeight
        case .standard:
            height = isLandscape ? KeyboardStyle.landscapeKeyHeight : KeyboardStyle.keyHeight
        }
        return height * zoom.sizeScale
    }

    /// The height of the toolbar buttons sized from the top key row in landscape: the keys'
    /// height, except on iPad, where the toolbar stays shorter than the keys.
    func toolbarButtonHeight(
        isLandscape: Bool,
        display: KeyboardDisplay = .standard,
        zoom: KeyboardDisplayZoom = .none
    ) -> CGFloat {
        guard isLandscape, display == .pad else {
            return keyHeight(isLandscape: isLandscape, display: display, zoom: zoom)
        }
        return KeyboardStyle.padLandscapeToolbarHeight * zoom.sizeScale
    }

    /// Key rows keep the same spacing everywhere except landscape on an open foldable's inner
    /// display, where they sit a little further apart. Under Display Zoom they shrink by the zoom.
    func rowSpacing(
        isLandscape: Bool,
        display: KeyboardDisplay = .standard,
        zoom: KeyboardDisplayZoom = .none
    ) -> CGFloat {
        let spacing = isLandscape && display == .openFoldable
            ? KeyboardStyle.openFoldableLandscapeRowSpacing
            : KeyboardStyle.keyboardRowSpacing
        return spacing * zoom.sizeScale
    }

    var visibleRowCount: Int {
        switch self {
        case .full:
            return 4
        case .compact:
            return 2
        }
    }

    func keyGridHeight(
        isLandscape: Bool,
        display: KeyboardDisplay = .standard,
        zoom: KeyboardDisplayZoom = .none
    ) -> CGFloat {
        let rowCount = CGFloat(visibleRowCount)
        let spacingCount = CGFloat(max(visibleRowCount - 1, 0))
        let keyHeight = keyHeight(isLandscape: isLandscape, display: display, zoom: zoom)
        let rowSpacing = rowSpacing(isLandscape: isLandscape, display: display, zoom: zoom)
        return (keyHeight * rowCount) + (rowSpacing * spacingCount)
    }
}
