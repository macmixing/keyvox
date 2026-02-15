import AppKit
import CoreGraphics
import Foundation
import QuartzCore

final class OverlayMotionController {
    // Keep these shared so double-click reset and fling impacts use the same bounce feel.
    private let resetOvershootMinimumDistance: CGFloat = 6
    private let resetOvershootMaximumDistance: CGFloat = 12
    private let resetOvershootDistanceRatio: CGFloat = 0.12
    private let resetSettleStartDelay: TimeInterval = 0.05
    private let resetSettleDuration: TimeInterval = 0.10
    private let resetSettleOverrideClearDelay: TimeInterval = 0.10
    private let flingMinimumSpeed: CGFloat = 1500
    private let flingMinimumTravelDistance: CGFloat = 36
    private let flingTravelDurationMin: TimeInterval = 0.12
    private let flingTravelDurationMax: TimeInterval = 0.30
    private let flingFlightFrameInterval: TimeInterval = 1.0 / 120.0

    private var flingFlightTimer: Timer?
    private var pendingResetWorkItem: DispatchWorkItem?

    private(set) var isProgrammaticMotionInFlight = false
    let flingVelocitySamplingWindow: TimeInterval = 0.12

    func handleFlingRelease(
        panel: NSPanel?,
        velocity: CGVector,
        screen: NSScreen,
        onMotionCompleted: @escaping (NSPanel) -> Void
    ) {
        guard let panel else { return }
        let speed = hypot(velocity.dx, velocity.dy)
        guard speed >= flingMinimumSpeed else { return }

        let currentOrigin = panel.frame.origin
        let visible = screen.visibleFrame
        let bounds = CGRect(
            x: visible.minX,
            y: visible.minY,
            width: max(0, visible.width - panel.frame.width),
            height: max(0, visible.height - panel.frame.height)
        )

        guard let impact = OverlayFlingPhysics.firstImpactResult(from: currentOrigin, velocity: velocity, bounds: bounds) else {
            return
        }

        let travelDistance = hypot(impact.originAtImpact.x - currentOrigin.x, impact.originAtImpact.y - currentOrigin.y)
        guard travelDistance >= flingMinimumTravelDistance else { return }

        cancelPendingMotionAnimations(panel: panel)
        beginProgrammaticMotion()

        let travelDuration = OverlayFlingPhysics.travelDuration(
            distance: travelDistance,
            speed: speed,
            minDuration: flingTravelDurationMin,
            maxDuration: flingTravelDurationMax
        )

        let bounceDirection = OverlayFlingPhysics.reflectedDirection(velocity: velocity, normal: impact.edge.normal)
        animateFlingFlight(
            panel: panel,
            from: currentOrigin,
            to: impact.originAtImpact,
            duration: travelDuration
        ) { [weak self, weak panel] in
            guard let self, let panel else { return }
            self.animateOvershootAndSettle(
                panel: panel,
                target: impact.originAtImpact,
                overshootDirection: bounceDirection,
                onMotionCompleted: onMotionCompleted
            )
        }
    }

    func moveToDefaultPosition(
        panel: NSPanel?,
        target: NSPoint,
        animated: Bool,
        onMotionCompleted: @escaping (NSPanel) -> Void
    ) {
        guard let panel else { return }

        if !animated {
            cancelPendingMotionAnimations(panel: panel)
            panel.setFrameOrigin(target)
            return
        }

        let current = panel.frame.origin
        let deltaX = target.x - current.x
        let deltaY = target.y - current.y
        let distance = hypot(deltaX, deltaY)

        guard distance > 1 else {
            panel.setFrameOrigin(target)
            return
        }

        cancelPendingMotionAnimations(panel: panel)
        beginProgrammaticMotion()
        let travelDirection = CGVector(dx: deltaX / distance, dy: deltaY / distance)
        animateOvershootAndSettle(
            panel: panel,
            target: target,
            overshootDirection: travelDirection,
            onMotionCompleted: onMotionCompleted
        )
    }

    func cancelPendingMotionAnimations(panel: NSPanel?) {
        flingFlightTimer?.invalidate()
        flingFlightTimer = nil
        pendingResetWorkItem?.cancel()
        pendingResetWorkItem = nil
        (panel as? OverlayPanel)?.frameAnimationDurationOverride = nil
        endProgrammaticMotion()
    }

    private func animateFlingFlight(
        panel: NSPanel,
        from startOrigin: NSPoint,
        to targetOrigin: NSPoint,
        duration: TimeInterval,
        completion: @escaping () -> Void
    ) {
        flingFlightTimer?.invalidate()
        flingFlightTimer = nil

        guard duration > 0.001 else {
            panel.setFrameOrigin(targetOrigin)
            completion()
            return
        }

        let startTime = CACurrentMediaTime()
        let deltaX = targetOrigin.x - startOrigin.x
        let deltaY = targetOrigin.y - startOrigin.y

        // Drive flight manually at 120 Hz; NSWindow animated frame updates can look stepped at fling speeds.
        let timer = Timer(timeInterval: flingFlightFrameInterval, repeats: true) { [weak self, weak panel] timer in
            guard let self, let panel else {
                timer.invalidate()
                return
            }

            let elapsed = CACurrentMediaTime() - startTime
            let linearProgress = max(0, min(1, elapsed / duration))
            let easedProgress = 1 - pow(1 - linearProgress, 3)
            let origin = NSPoint(
                x: startOrigin.x + (deltaX * easedProgress),
                y: startOrigin.y + (deltaY * easedProgress)
            )
            panel.setFrameOrigin(origin)

            if linearProgress >= 1 {
                timer.invalidate()
                self.flingFlightTimer = nil
                completion()
            }
        }

        flingFlightTimer = timer
        RunLoop.main.add(timer, forMode: .common)
    }

    private func animateOvershootAndSettle(
        panel: NSPanel,
        target: NSPoint,
        overshootDirection: CGVector,
        onMotionCompleted: @escaping (NSPanel) -> Void
    ) {
        let directionLength = hypot(overshootDirection.dx, overshootDirection.dy)
        let fallbackLength = hypot(target.x - panel.frame.origin.x, target.y - panel.frame.origin.y)

        let unitDirection: CGVector
        if directionLength > 0.0001 {
            unitDirection = CGVector(dx: overshootDirection.dx / directionLength, dy: overshootDirection.dy / directionLength)
        } else if fallbackLength > 0.0001 {
            unitDirection = CGVector(
                dx: (target.x - panel.frame.origin.x) / fallbackLength,
                dy: (target.y - panel.frame.origin.y) / fallbackLength
            )
        } else {
            unitDirection = CGVector(dx: 0, dy: 1)
        }

        let distanceToTarget = hypot(target.x - panel.frame.origin.x, target.y - panel.frame.origin.y)
        let overshootDistance = min(
            resetOvershootMaximumDistance,
            max(resetOvershootMinimumDistance, distanceToTarget * resetOvershootDistanceRatio)
        )
        let overshoot = NSPoint(
            x: target.x + (unitDirection.dx * overshootDistance),
            y: target.y + (unitDirection.dy * overshootDistance)
        )
        let overshootFrame = NSRect(origin: overshoot, size: panel.frame.size)
        let targetFrame = NSRect(origin: target, size: panel.frame.size)

        (panel as? OverlayPanel)?.frameAnimationDurationOverride = nil
        panel.setFrame(overshootFrame, display: true, animate: true)

        let settleWorkItem = DispatchWorkItem { [weak panel] in
            guard let panel else { return }
            if let overlayPanel = panel as? OverlayPanel {
                overlayPanel.frameAnimationDurationOverride = self.resetSettleDuration
            }
            panel.setFrame(targetFrame, display: true, animate: true)
            let completionDelay = max(self.resetSettleDuration, self.resetSettleOverrideClearDelay)
            DispatchQueue.main.asyncAfter(deadline: .now() + completionDelay) { [weak self, weak panel] in
                guard let self, let panel else { return }
                (panel as? OverlayPanel)?.frameAnimationDurationOverride = nil
                self.completeProgrammaticMotion(panel: panel, onMotionCompleted: onMotionCompleted)
            }
        }
        pendingResetWorkItem = settleWorkItem
        DispatchQueue.main.asyncAfter(deadline: .now() + resetSettleStartDelay, execute: settleWorkItem)
    }

    private func beginProgrammaticMotion() {
        isProgrammaticMotionInFlight = true
    }

    private func endProgrammaticMotion() {
        isProgrammaticMotionInFlight = false
    }

    private func completeProgrammaticMotion(panel: NSPanel, onMotionCompleted: (NSPanel) -> Void) {
        onMotionCompleted(panel)
        endProgrammaticMotion()
    }
}
