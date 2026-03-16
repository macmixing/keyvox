import UIKit

final class KeyboardHitTargetButton: UIButton {
    var minimumHitTargetSize = CGSize(width: 60, height: 60)

    override func point(inside point: CGPoint, with event: UIEvent?) -> Bool {
        let widthToAdd = max(minimumHitTargetSize.width - bounds.width, 0)
        let heightToAdd = max(minimumHitTargetSize.height - bounds.height, 0)
        let expandedBounds = bounds.insetBy(dx: -widthToAdd / 2, dy: -heightToAdd / 2)
        return expandedBounds.contains(point)
    }
}
