import AppKit
import CoreGraphics

final class OverlayPanel: NSPanel {
    private struct DragSample {
        let point: NSPoint
        let timestamp: TimeInterval
    }

    var onDragBegan: (() -> Void)?
    var onDoubleClick: (() -> Void)?
    var onDragReleaseVelocity: ((CGVector) -> Void)?
    var frameAnimationDurationOverride: TimeInterval?
    var dragVelocitySamplingWindow: TimeInterval = 0.12
    private var dragSamples: [DragSample] = []

    override func animationResizeTime(_ newFrame: NSRect) -> TimeInterval {
        frameAnimationDurationOverride ?? super.animationResizeTime(newFrame)
    }

    override func sendEvent(_ event: NSEvent) {
        switch event.type {
        case .leftMouseDown:
            if event.clickCount == 2 {
                onDoubleClick?()
                return
            }
            if event.clickCount == 1 {
                beginDragSampling(at: NSEvent.mouseLocation, timestamp: event.timestamp)
                onDragBegan?()
            }
        case .leftMouseDragged:
            appendDragSample(point: NSEvent.mouseLocation, timestamp: event.timestamp)
        case .leftMouseUp:
            appendDragSample(point: NSEvent.mouseLocation, timestamp: event.timestamp)
            if let velocity = releaseVelocity() {
                onDragReleaseVelocity?(velocity)
            }
            clearDragSampling()
        default:
            break
        }
        super.sendEvent(event)
    }

    private func beginDragSampling(at point: NSPoint, timestamp: TimeInterval) {
        dragSamples = [DragSample(point: point, timestamp: timestamp)]
    }

    private func appendDragSample(point: NSPoint, timestamp: TimeInterval) {
        guard !dragSamples.isEmpty else { return }
        dragSamples.append(DragSample(point: point, timestamp: timestamp))
    }

    private func clearDragSampling() {
        dragSamples.removeAll(keepingCapacity: true)
    }

    private func releaseVelocity() -> CGVector? {
        guard dragSamples.count >= 2, let latest = dragSamples.last else { return nil }
        let windowStart = latest.timestamp - dragVelocitySamplingWindow
        let recentSamples = dragSamples.filter { $0.timestamp >= windowStart }
        guard let first = recentSamples.first ?? dragSamples.first,
              let last = recentSamples.last ?? dragSamples.last else {
            return nil
        }

        let dt = last.timestamp - first.timestamp
        guard dt > 0.008 else { return nil }

        let dx = last.point.x - first.point.x
        let dy = last.point.y - first.point.y
        guard hypot(dx, dy) > 1 else { return nil }

        return CGVector(dx: dx / CGFloat(dt), dy: dy / CGFloat(dt))
    }
}
