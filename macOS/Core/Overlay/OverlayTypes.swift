import AppKit
import CoreGraphics

enum FlingImpactEdge: Equatable {
    case left
    case right
    case bottom
    case top

    var normal: CGVector {
        switch self {
        case .left: return CGVector(dx: 1, dy: 0)
        case .right: return CGVector(dx: -1, dy: 0)
        case .bottom: return CGVector(dx: 0, dy: 1)
        case .top: return CGVector(dx: 0, dy: -1)
        }
    }
}

struct FlingImpactResult {
    let edge: FlingImpactEdge
    let timeToImpact: CGFloat
    let originAtImpact: NSPoint
}
