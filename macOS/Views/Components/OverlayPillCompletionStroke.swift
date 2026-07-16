import SwiftUI

struct OverlayPillCompletionStroke: Shape {
    var progress: Double

    var animatableData: Double {
        get { progress }
        set { progress = newValue }
    }

    func path(in rect: CGRect) -> Path {
        let lineInset: CGFloat = 1
        let rect = rect.insetBy(dx: lineInset, dy: lineInset)
        let radius = rect.height / 2
        let topCenter = CGPoint(x: rect.midX, y: rect.minY)

        var path = Path()
        path.move(to: topCenter)
        path.addLine(to: CGPoint(x: rect.maxX - radius, y: rect.minY))
        path.addArc(
            center: CGPoint(x: rect.maxX - radius, y: rect.midY),
            radius: radius,
            startAngle: .degrees(-90),
            endAngle: .degrees(90),
            clockwise: false
        )
        path.addLine(to: CGPoint(x: rect.minX + radius, y: rect.maxY))
        path.addArc(
            center: CGPoint(x: rect.minX + radius, y: rect.midY),
            radius: radius,
            startAngle: .degrees(90),
            endAngle: .degrees(270),
            clockwise: false
        )
        path.addLine(to: topCenter)

        return path.trimmedPath(from: 0, to: progress)
    }
}
