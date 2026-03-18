import AppKit
import CoreGraphics
import Foundation

enum OverlayFlingPhysics {
    private static let impactEpsilon: CGFloat = 0.0001
    private static let impactInsetTolerance: CGFloat = 0.5

    static func firstImpactResult(
        from origin: NSPoint,
        velocity: CGVector,
        bounds: CGRect
    ) -> FlingImpactResult? {
        var candidates = [FlingImpactResult]()

        if velocity.dx > impactEpsilon {
            let t = (bounds.maxX - origin.x) / velocity.dx
            if t > impactEpsilon {
                let y = origin.y + (velocity.dy * t)
                if y >= (bounds.minY - impactInsetTolerance), y <= (bounds.maxY + impactInsetTolerance) {
                    let impact = NSPoint(x: bounds.maxX, y: min(max(y, bounds.minY), bounds.maxY))
                    candidates.append(FlingImpactResult(edge: .right, timeToImpact: t, originAtImpact: impact))
                }
            }
        } else if velocity.dx < -impactEpsilon {
            let t = (bounds.minX - origin.x) / velocity.dx
            if t > impactEpsilon {
                let y = origin.y + (velocity.dy * t)
                if y >= (bounds.minY - impactInsetTolerance), y <= (bounds.maxY + impactInsetTolerance) {
                    let impact = NSPoint(x: bounds.minX, y: min(max(y, bounds.minY), bounds.maxY))
                    candidates.append(FlingImpactResult(edge: .left, timeToImpact: t, originAtImpact: impact))
                }
            }
        }

        if velocity.dy > impactEpsilon {
            let t = (bounds.maxY - origin.y) / velocity.dy
            if t > impactEpsilon {
                let x = origin.x + (velocity.dx * t)
                if x >= (bounds.minX - impactInsetTolerance), x <= (bounds.maxX + impactInsetTolerance) {
                    let impact = NSPoint(x: min(max(x, bounds.minX), bounds.maxX), y: bounds.maxY)
                    candidates.append(FlingImpactResult(edge: .top, timeToImpact: t, originAtImpact: impact))
                }
            }
        } else if velocity.dy < -impactEpsilon {
            let t = (bounds.minY - origin.y) / velocity.dy
            if t > impactEpsilon {
                let x = origin.x + (velocity.dx * t)
                if x >= (bounds.minX - impactInsetTolerance), x <= (bounds.maxX + impactInsetTolerance) {
                    let impact = NSPoint(x: min(max(x, bounds.minX), bounds.maxX), y: bounds.minY)
                    candidates.append(FlingImpactResult(edge: .bottom, timeToImpact: t, originAtImpact: impact))
                }
            }
        }

        return candidates.min(by: { $0.timeToImpact < $1.timeToImpact })
    }

    static func reflectedDirection(velocity: CGVector, normal: CGVector) -> CGVector {
        let dot = (velocity.dx * normal.dx) + (velocity.dy * normal.dy)
        let reflected = CGVector(
            dx: velocity.dx - (2 * dot * normal.dx),
            dy: velocity.dy - (2 * dot * normal.dy)
        )
        let length = hypot(reflected.dx, reflected.dy)
        guard length > impactEpsilon else {
            return normal
        }
        return CGVector(dx: reflected.dx / length, dy: reflected.dy / length)
    }

    static func travelDuration(
        distance: CGFloat,
        speed: CGFloat,
        minDuration: TimeInterval,
        maxDuration: TimeInterval
    ) -> TimeInterval {
        max(minDuration, min(maxDuration, TimeInterval(distance / max(speed, 1))))
    }
}
