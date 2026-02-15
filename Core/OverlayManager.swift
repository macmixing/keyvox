import AppKit
import Combine
import CoreGraphics
import SwiftUI

class OverlayVisibilityManager: ObservableObject {
    @Published var isVisible: Bool = false
    @Published var shouldDismiss: Bool = false
}

class OverlayManager {
    static let shared = OverlayManager()
    private var window: OverlayPanel?
    private var visibilityManager = OverlayVisibilityManager()
    private var pendingHideWorkItem: DispatchWorkItem?
    private var flingFlightTimer: Timer?
    private var pendingResetWorkItem: DispatchWorkItem?
    private var moveObserver: NSObjectProtocol?
    private var screenParamsObserver: NSObjectProtocol?
    private var isProgrammaticMotionInFlight = false
    private var isUsingFallbackDisplay: Bool = false
    private var hasLoadedPreferredDisplayKey = false
    private var preferredDisplayKeyCache: String?
    private var hasLoadedOriginsByDisplay = false
    private var originsByDisplayCache: [String: NSPoint] = [:]
    private let hideAnimationCompletionDelay: TimeInterval = 0.5
    private let clampOriginThreshold: CGFloat = 0.5
    private let resetOvershootMinimumDistance: CGFloat = 6
    private let resetOvershootMaximumDistance: CGFloat = 12
    private let resetOvershootDistanceRatio: CGFloat = 0.12
    private let defaultVerticalOffset: CGFloat = 50
    // Step 2 settle tuning (overshoot return leg only).
    private let resetSettleStartDelay: TimeInterval = 0.05
    private let resetSettleDuration: TimeInterval = 0.10
    private let resetSettleOverrideClearDelay: TimeInterval = 0.10
    private let flingVelocitySamplingWindow: TimeInterval = 0.12
    private let flingMinimumSpeed: CGFloat = 1500
    private let flingMinimumTravelDistance: CGFloat = 36
    private let flingTravelDurationMin: TimeInterval = 0.12
    private let flingTravelDurationMax: TimeInterval = 0.30
    private let flingFlightFrameInterval: TimeInterval = 1.0 / 120.0

    func show(recorder: AudioRecorder, isTranscribing: Bool = false) {
        pendingHideWorkItem?.cancel()
        pendingHideWorkItem = nil

        if window == nil {
            let panelSize = RecordingOverlay.panelSize
            let panel = OverlayPanel(
                contentRect: NSRect(origin: .zero, size: panelSize),
                styleMask: [.nonactivatingPanel, .fullSizeContentView],
                backing: .buffered,
                defer: false
            )
            panel.isFloatingPanel = true
            panel.level = .floating
            panel.isReleasedWhenClosed = false
            panel.backgroundColor = .clear
            panel.hasShadow = false
            panel.isMovableByWindowBackground = true
            panel.dragVelocitySamplingWindow = flingVelocitySamplingWindow
            panel.onDragBegan = { [weak self, weak panel] in
                self?.cancelPendingMotionAnimations(panel: panel)
            }
            panel.onDoubleClick = { [weak self, weak panel] in
                self?.moveToDefaultPosition(panel, animated: true)
            }
            panel.onDragReleaseVelocity = { [weak self, weak panel] velocity in
                self?.handleFlingRelease(panel, velocity: velocity)
            }

            let contentView = NSHostingView(rootView: RecordingOverlay(
                recorder: recorder,
                isTranscribing: isTranscribing,
                visibilityManager: visibilityManager
            ))
            panel.contentView = contentView
            registerMoveObserverIfNeeded(for: panel)
            registerScreenParamsObserverIfNeeded(for: panel)
            window = panel
        }

        // Always update the content view to ensure binding is fresh
        window?.contentView = NSHostingView(rootView: RecordingOverlay(
            recorder: recorder,
            isTranscribing: isTranscribing,
            visibilityManager: visibilityManager
        ))

        // Reset state for showing
        visibilityManager.shouldDismiss = false
        visibilityManager.isVisible = true
        if let panel = window {
            panel.dragVelocitySamplingWindow = flingVelocitySamplingWindow
            panel.onDragBegan = { [weak self, weak panel] in
                self?.cancelPendingMotionAnimations(panel: panel)
            }
            panel.onDragReleaseVelocity = { [weak self, weak panel] velocity in
                self?.handleFlingRelease(panel, velocity: velocity)
            }
            panel.setFrameOrigin(resolvedOriginForShow(panel: panel))
            panel.orderFrontRegardless()
        }
    }

    func hide() {
        pendingHideWorkItem?.cancel()
        cancelPendingMotionAnimations(panel: window)

        // Trigger the hide animation first
        visibilityManager.isVisible = false
        visibilityManager.shouldDismiss = true

        // Wait for animation to complete before actually hiding the window
        let workItem = DispatchWorkItem { [weak self] in
            self?.window?.orderOut(nil)
            self?.pendingHideWorkItem = nil
        }
        pendingHideWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + hideAnimationCompletionDelay, execute: workItem)
    }

    private enum FlingImpactEdge {
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

    private struct FlingImpactResult {
        let edge: FlingImpactEdge
        let timeToImpact: CGFloat
        let originAtImpact: NSPoint
    }

    private func handleFlingRelease(_ panel: NSPanel?, velocity: CGVector) {
        guard let panel else { return }
        let speed = hypot(velocity.dx, velocity.dy)
        guard speed >= flingMinimumSpeed else { return }

        let currentOrigin = panel.frame.origin
        let center = NSPoint(x: panel.frame.midX, y: panel.frame.midY)
        guard let screen = screenContaining(point: center) ?? panel.screen ?? NSScreen.main ?? NSScreen.screens.first else {
            return
        }

        let visible = screen.visibleFrame
        let bounds = CGRect(
            x: visible.minX,
            y: visible.minY,
            width: max(0, visible.width - panel.frame.width),
            height: max(0, visible.height - panel.frame.height)
        )

        guard let impact = firstImpactResult(from: currentOrigin, velocity: velocity, bounds: bounds) else {
            return
        }

        let travelDistance = hypot(impact.originAtImpact.x - currentOrigin.x, impact.originAtImpact.y - currentOrigin.y)
        guard travelDistance >= flingMinimumTravelDistance else { return }

        cancelPendingMotionAnimations(panel: panel)
        beginProgrammaticMotion()

        let travelDuration = max(
            flingTravelDurationMin,
            min(flingTravelDurationMax, TimeInterval(travelDistance / max(speed, 1)))
        )

        let bounceDirection = reflectedDirection(velocity: velocity, normal: impact.edge.normal)
        animateFlingFlight(
            panel: panel,
            from: currentOrigin,
            to: impact.originAtImpact,
            duration: travelDuration
        ) { [weak self, weak panel] in
            guard let self, let panel else { return }
            self.animateOvershootAndSettle(panel: panel, target: impact.originAtImpact, overshootDirection: bounceDirection)
        }
    }

    private func firstImpactResult(
        from origin: NSPoint,
        velocity: CGVector,
        bounds: CGRect
    ) -> FlingImpactResult? {
        let epsilon: CGFloat = 0.0001
        var candidates = [FlingImpactResult]()

        if velocity.dx > epsilon {
            let t = (bounds.maxX - origin.x) / velocity.dx
            if t > epsilon {
                let y = origin.y + (velocity.dy * t)
                if y >= (bounds.minY - 0.5), y <= (bounds.maxY + 0.5) {
                    let impact = NSPoint(x: bounds.maxX, y: min(max(y, bounds.minY), bounds.maxY))
                    candidates.append(FlingImpactResult(edge: .right, timeToImpact: t, originAtImpact: impact))
                }
            }
        } else if velocity.dx < -epsilon {
            let t = (bounds.minX - origin.x) / velocity.dx
            if t > epsilon {
                let y = origin.y + (velocity.dy * t)
                if y >= (bounds.minY - 0.5), y <= (bounds.maxY + 0.5) {
                    let impact = NSPoint(x: bounds.minX, y: min(max(y, bounds.minY), bounds.maxY))
                    candidates.append(FlingImpactResult(edge: .left, timeToImpact: t, originAtImpact: impact))
                }
            }
        }

        if velocity.dy > epsilon {
            let t = (bounds.maxY - origin.y) / velocity.dy
            if t > epsilon {
                let x = origin.x + (velocity.dx * t)
                if x >= (bounds.minX - 0.5), x <= (bounds.maxX + 0.5) {
                    let impact = NSPoint(x: min(max(x, bounds.minX), bounds.maxX), y: bounds.maxY)
                    candidates.append(FlingImpactResult(edge: .top, timeToImpact: t, originAtImpact: impact))
                }
            }
        } else if velocity.dy < -epsilon {
            let t = (bounds.minY - origin.y) / velocity.dy
            if t > epsilon {
                let x = origin.x + (velocity.dx * t)
                if x >= (bounds.minX - 0.5), x <= (bounds.maxX + 0.5) {
                    let impact = NSPoint(x: min(max(x, bounds.minX), bounds.maxX), y: bounds.minY)
                    candidates.append(FlingImpactResult(edge: .bottom, timeToImpact: t, originAtImpact: impact))
                }
            }
        }

        return candidates.min(by: { $0.timeToImpact < $1.timeToImpact })
    }

    private func reflectedDirection(velocity: CGVector, normal: CGVector) -> CGVector {
        let dot = (velocity.dx * normal.dx) + (velocity.dy * normal.dy)
        let reflected = CGVector(
            dx: velocity.dx - (2 * dot * normal.dx),
            dy: velocity.dy - (2 * dot * normal.dy)
        )
        let length = hypot(reflected.dx, reflected.dy)
        guard length > 0.0001 else {
            return normal
        }
        return CGVector(dx: reflected.dx / length, dy: reflected.dy / length)
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

    private func cancelPendingMotionAnimations(panel: NSPanel?) {
        flingFlightTimer?.invalidate()
        flingFlightTimer = nil
        pendingResetWorkItem?.cancel()
        pendingResetWorkItem = nil
        (panel as? OverlayPanel)?.frameAnimationDurationOverride = nil
        endProgrammaticMotion()
    }

    private func beginProgrammaticMotion() {
        isProgrammaticMotionInFlight = true
    }

    private func endProgrammaticMotion() {
        isProgrammaticMotionInFlight = false
    }

    private func completeProgrammaticMotion(panel: NSPanel) {
        persistPanelLocation(panel)
        endProgrammaticMotion()
    }

    private func persistPanelLocation(_ panel: NSPanel) {
        let center = NSPoint(x: panel.frame.midX, y: panel.frame.midY)
        guard let currentScreen = screenContaining(point: center) ?? panel.screen ?? NSScreen.main ?? NSScreen.screens.first,
              let key = displayKey(for: currentScreen) else {
            return
        }

        saveOrigin(panel.frame.origin, for: key)

        if let preferredKey = loadPreferredDisplayKey(),
           screen(forDisplayKey: preferredKey) == nil {
            isUsingFallbackDisplay = true
            return
        }

        savePreferredDisplayKey(key)
        isUsingFallbackDisplay = false
    }

    private func registerMoveObserverIfNeeded(for panel: NSPanel) {
        guard moveObserver == nil else { return }
        moveObserver = NotificationCenter.default.addObserver(
            forName: NSWindow.didMoveNotification,
            object: panel,
            queue: .main
        ) { [weak self] _ in
            self?.handlePanelMove(panel)
        }
    }

    private func registerScreenParamsObserverIfNeeded(for panel: NSPanel) {
        guard screenParamsObserver == nil else { return }
        screenParamsObserver = NotificationCenter.default.addObserver(
            forName: NSApplication.didChangeScreenParametersNotification,
            object: nil,
            queue: .main
        ) { [weak self, weak panel] _ in
            guard let self, let panel else { return }
            self.handleScreenParametersChanged(for: panel)
        }
    }

    private func handlePanelMove(_ panel: NSPanel) {
        guard !isProgrammaticMotionInFlight else {
            return
        }
        persistPanelLocation(panel)
    }

    private func handleScreenParametersChanged(for panel: NSPanel) {
        guard let preferredKey = loadPreferredDisplayKey() else {
            if panel.isVisible { clampPanelToVisibleBounds(panel) }
            return
        }

        if let preferredScreen = screen(forDisplayKey: preferredKey) {
            if isUsingFallbackDisplay, panel.isVisible {
                let origin = savedOrigin(for: preferredKey) ?? defaultOrigin(for: panel, on: preferredScreen)
                panel.setFrameOrigin(clampedOrigin(origin, for: panel, on: preferredScreen))
                isUsingFallbackDisplay = false
            } else if panel.isVisible {
                clampPanelToVisibleBounds(panel)
            }
            return
        }

        isUsingFallbackDisplay = true
        if panel.isVisible {
            clampPanelToVisibleBounds(panel)
        }
    }

    private func clampPanelToVisibleBounds(_ panel: NSPanel) {
        let center = NSPoint(x: panel.frame.midX, y: panel.frame.midY)
        guard let screen = screenContaining(point: center) ?? panel.screen ?? NSScreen.main ?? NSScreen.screens.first else {
            return
        }

        let clamped = clampedOrigin(panel.frame.origin, for: panel, on: screen)
        if abs(clamped.x - panel.frame.origin.x) > clampOriginThreshold || abs(clamped.y - panel.frame.origin.y) > clampOriginThreshold {
            panel.setFrameOrigin(clamped)
        }
    }

    private func resolvedOriginForShow(panel: NSPanel) -> NSPoint {
        let preferredKey = loadPreferredDisplayKey()
        if let preferredKey,
           let preferredScreen = screen(forDisplayKey: preferredKey) {
            isUsingFallbackDisplay = false
            let origin = savedOrigin(for: preferredKey) ?? defaultOrigin(for: panel, on: preferredScreen)
            return clampedOrigin(origin, for: panel, on: preferredScreen)
        }

        guard let fallbackScreen = panel.screen ?? NSScreen.main ?? NSScreen.screens.first else {
            return panel.frame.origin
        }

        isUsingFallbackDisplay = (preferredKey != nil)
        if let fallbackKey = displayKey(for: fallbackScreen),
           let origin = savedOrigin(for: fallbackKey) {
            return clampedOrigin(origin, for: panel, on: fallbackScreen)
        }

        return clampedOrigin(defaultOrigin(for: panel, on: fallbackScreen), for: panel, on: fallbackScreen)
    }

    private func moveToDefaultPosition(_ panel: NSPanel?, animated: Bool) {
        guard let panel else { return }
        let target = defaultOrigin(for: panel)

        if !animated {
            cancelPendingMotionAnimations(panel: panel)
            panel.setFrameOrigin(target)
            return
        }

        let current = panel.frame.origin
        let deltaX = target.x - current.x
        let deltaY = target.y - current.y
        let distance = hypot(deltaX, deltaY)

        // Avoid animation churn when we are effectively already at the default spot.
        guard distance > 1 else {
            panel.setFrameOrigin(target)
            return
        }

        cancelPendingMotionAnimations(panel: panel)
        beginProgrammaticMotion()
        // Overshoot in the same direction as travel so the return path stays natural.
        let travelDirection = CGVector(dx: deltaX / distance, dy: deltaY / distance)
        animateOvershootAndSettle(panel: panel, target: target, overshootDirection: travelDirection)
    }

    private func animateOvershootAndSettle(panel: NSPanel, target: NSPoint, overshootDirection: CGVector) {
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

        // Step 1: quick "buzz" overshoot.
        (panel as? OverlayPanel)?.frameAnimationDurationOverride = nil
        panel.setFrame(overshootFrame, display: true, animate: true)

        // Step 2: settle back to the exact target location.
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
                self.completeProgrammaticMotion(panel: panel)
            }
        }
        pendingResetWorkItem = settleWorkItem
        DispatchQueue.main.asyncAfter(deadline: .now() + resetSettleStartDelay, execute: settleWorkItem)
    }

    private func defaultOrigin(for panel: NSPanel) -> NSPoint {
        guard let screen = panel.screen ?? NSScreen.main ?? NSScreen.screens.first else {
            return panel.frame.origin
        }
        return defaultOrigin(for: panel, on: screen)
    }

    private func defaultOrigin(for panel: NSPanel, on screen: NSScreen) -> NSPoint {
        let rect = screen.visibleFrame
        return NSPoint(
            x: rect.midX - (panel.frame.width / 2),
            y: rect.minY + defaultVerticalOffset
        )
    }

    private func clampedOrigin(_ origin: NSPoint, for panel: NSPanel, on screen: NSScreen) -> NSPoint {
        let visible = screen.visibleFrame
        let maxX = max(visible.minX, visible.maxX - panel.frame.width)
        let maxY = max(visible.minY, visible.maxY - panel.frame.height)
        return NSPoint(
            x: min(max(origin.x, visible.minX), maxX),
            y: min(max(origin.y, visible.minY), maxY)
        )
    }

    private func savePreferredDisplayKey(_ key: String) {
        preferredDisplayKeyCache = key
        hasLoadedPreferredDisplayKey = true
        UserDefaults.standard.set(key, forKey: UserDefaultsKeys.recordingOverlayPreferredDisplayKey)
    }

    private func loadPreferredDisplayKey() -> String? {
        if hasLoadedPreferredDisplayKey {
            return preferredDisplayKeyCache
        }
        preferredDisplayKeyCache = UserDefaults.standard.string(forKey: UserDefaultsKeys.recordingOverlayPreferredDisplayKey)
        hasLoadedPreferredDisplayKey = true
        return preferredDisplayKeyCache
    }

    private func saveOriginsByDisplay(_ origins: [String: NSPoint]) {
        originsByDisplayCache = origins
        hasLoadedOriginsByDisplay = true
        let serialized = origins.mapValues { [$0.x, $0.y] }
        UserDefaults.standard.set(serialized, forKey: UserDefaultsKeys.recordingOverlayOriginsByDisplay)
    }

    private func loadOriginsByDisplay() -> [String: NSPoint] {
        if hasLoadedOriginsByDisplay {
            return originsByDisplayCache
        }

        let defaults = UserDefaults.standard
        var origins = [String: NSPoint]()
        if let raw = defaults.dictionary(forKey: UserDefaultsKeys.recordingOverlayOriginsByDisplay) {
            for (key, value) in raw {
                if let doubles = value as? [Double], doubles.count == 2 {
                    origins[key] = NSPoint(x: doubles[0], y: doubles[1])
                    continue
                }
                if let numbers = value as? [NSNumber], numbers.count == 2 {
                    origins[key] = NSPoint(x: numbers[0].doubleValue, y: numbers[1].doubleValue)
                }
            }
        }

        if origins.isEmpty,
           let legacyOrigin = loadLegacySavedOrigin(),
           let screen = screenContaining(point: legacyOrigin) ?? NSScreen.main ?? NSScreen.screens.first,
           let displayKey = displayKey(for: screen) {
            origins[displayKey] = legacyOrigin
            saveOriginsByDisplay(origins)
            if loadPreferredDisplayKey() == nil {
                savePreferredDisplayKey(displayKey)
            }
        } else {
            originsByDisplayCache = origins
            hasLoadedOriginsByDisplay = true
        }

        return originsByDisplayCache
    }

    private func savedOrigin(for key: String) -> NSPoint? {
        loadOriginsByDisplay()[key]
    }

    private func saveOrigin(_ origin: NSPoint, for key: String) {
        var origins = loadOriginsByDisplay()
        origins[key] = origin
        saveOriginsByDisplay(origins)
    }

    private func loadLegacySavedOrigin() -> NSPoint? {
        if let numbers = UserDefaults.standard.array(forKey: UserDefaultsKeys.recordingOverlayOrigin) as? [NSNumber],
           numbers.count == 2 {
            return NSPoint(x: numbers[0].doubleValue, y: numbers[1].doubleValue)
        }

        if let doubles = UserDefaults.standard.array(forKey: UserDefaultsKeys.recordingOverlayOrigin) as? [Double],
           doubles.count == 2 {
            return NSPoint(x: doubles[0], y: doubles[1])
        }

        return nil
    }

    private func displayID(for screen: NSScreen) -> CGDirectDisplayID? {
        guard let number = screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber else {
            return nil
        }
        return CGDirectDisplayID(number.uint32Value)
    }

    private func displayKey(for screen: NSScreen) -> String? {
        guard let id = displayID(for: screen) else { return nil }
        if let uuid = CGDisplayCreateUUIDFromDisplayID(id)?.takeRetainedValue() {
            return CFUUIDCreateString(nil, uuid) as String
        }
        return "display-id-\(id)"
    }

    private func screen(forDisplayKey key: String) -> NSScreen? {
        NSScreen.screens.first { screen in
            displayKey(for: screen) == key
        }
    }

    private func screenContaining(point: NSPoint) -> NSScreen? {
        NSScreen.screens.first(where: { $0.visibleFrame.contains(point) }) ?? NSScreen.main
    }
}

private final class OverlayPanel: NSPanel {
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
