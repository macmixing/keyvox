import UIKit

/// The outline of an emoji picker: a rounded panel and, when the picker has one, the stem that joins
/// it to the held emoji, filled as one shape.
enum KeyboardEmojiPickerPanelShape {
    static func path(panel: CGRect, stem: CGRect?, panelCornerRadius: CGFloat, stemCornerRadius: CGFloat) -> UIBezierPath {
        let path = UIBezierPath(roundedRect: panel, cornerRadius: panelCornerRadius)
        if let stem {
            // The stem starts under the panel so the two fill as one shape.
            path.append(UIBezierPath(
                roundedRect: CGRect(x: stem.minX, y: stem.minY - stemCornerRadius, width: stem.width, height: stem.height + stemCornerRadius),
                byRoundingCorners: [.bottomLeft, .bottomRight],
                cornerRadii: CGSize(width: stemCornerRadius, height: stemCornerRadius)
            ))
        }
        return path
    }
}
