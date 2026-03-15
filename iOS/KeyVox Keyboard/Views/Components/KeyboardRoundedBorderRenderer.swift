import UIKit

final class KeyboardRoundedBorderRenderer {
    private let shapeLayer = CAShapeLayer()
    private unowned let containerView: UIView

    var strokeColor: CGColor? {
        get { shapeLayer.strokeColor }
        set { shapeLayer.strokeColor = newValue }
    }

    init(containerView: UIView) {
        self.containerView = containerView
        shapeLayer.fillColor = UIColor.clear.cgColor
        shapeLayer.lineJoin = .round
        containerView.layer.addSublayer(shapeLayer)
    }

    func updatePath(cornerRadius: CGFloat, borderWidth: CGFloat) {
        let scale = containerView.window?.screen.scale ?? UIScreen.main.scale
        let safeScale = max(scale, 1)
        let lineWidth = max(
            (borderWidth * safeScale).rounded() / safeScale,
            1 / safeScale
        )
        let inset = lineWidth / 2

        shapeLayer.frame = containerView.bounds
        shapeLayer.contentsScale = scale
        shapeLayer.lineWidth = lineWidth
        shapeLayer.path = UIBezierPath(
            roundedRect: containerView.bounds.insetBy(dx: inset, dy: inset),
            cornerRadius: max(cornerRadius - inset, 0)
        ).cgPath
    }
}
