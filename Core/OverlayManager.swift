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
    private var pendingResetWorkItem: DispatchWorkItem?
    private var moveObserver: NSObjectProtocol?
    private var screenParamsObserver: NSObjectProtocol?
    private var isUsingFallbackDisplay: Bool = false
    private var hasLoadedPreferredDisplayKey = false
    private var preferredDisplayKeyCache: String?
    private var hasLoadedOriginsByDisplay = false
    private var originsByDisplayCache: [String: NSPoint] = [:]
    // Step 2 settle tuning (overshoot return leg only).
    private let resetSettleStartDelay: TimeInterval = 0.05
    private let resetSettleDuration: TimeInterval = 0.10
    private let resetSettleOverrideClearDelay: TimeInterval = 0.10

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
            panel.onDoubleClick = { [weak self, weak panel] in
                self?.moveToDefaultPosition(panel, animated: true)
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
            panel.setFrameOrigin(resolvedOriginForShow(panel: panel))
            panel.orderFrontRegardless()
        }
    }

    func hide() {
        pendingHideWorkItem?.cancel()

        // Trigger the hide animation first
        visibilityManager.isVisible = false
        visibilityManager.shouldDismiss = true

        // Wait for animation to complete before actually hiding the window
        let workItem = DispatchWorkItem { [weak self] in
            self?.window?.orderOut(nil)
            self?.pendingHideWorkItem = nil
        }
        pendingHideWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5, execute: workItem)
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
        if abs(clamped.x - panel.frame.origin.x) > 0.5 || abs(clamped.y - panel.frame.origin.y) > 0.5 {
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
            pendingResetWorkItem?.cancel()
            pendingResetWorkItem = nil
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

        pendingResetWorkItem?.cancel()
        // Overshoot in the same direction as travel so the return path stays natural.
        let unitX = deltaX / distance
        let unitY = deltaY / distance
        let overshootDistance = min(12, max(6, distance * 0.12))
        let overshoot = NSPoint(
            x: target.x + unitX * overshootDistance,
            y: target.y + unitY * overshootDistance
        )
        let overshootFrame = NSRect(origin: overshoot, size: panel.frame.size)
        let targetFrame = NSRect(origin: target, size: panel.frame.size)

        // Step 1: quick "buzz" overshoot toward the default anchor.
        (panel as? OverlayPanel)?.frameAnimationDurationOverride = nil
        panel.setFrame(overshootFrame, display: true, animate: true)

        // Step 2: settle back to the exact default location.
        let settleWorkItem = DispatchWorkItem { [weak panel] in
            guard let panel else { return }
            if let overlayPanel = panel as? OverlayPanel {
                overlayPanel.frameAnimationDurationOverride = self.resetSettleDuration
            }
            panel.setFrame(targetFrame, display: true, animate: true)
            DispatchQueue.main.asyncAfter(deadline: .now() + self.resetSettleOverrideClearDelay) { [weak panel] in
                (panel as? OverlayPanel)?.frameAnimationDurationOverride = nil
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
            y: rect.minY + 50
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
    var onDoubleClick: (() -> Void)?
    var frameAnimationDurationOverride: TimeInterval?

    override func animationResizeTime(_ newFrame: NSRect) -> TimeInterval {
        frameAnimationDurationOverride ?? super.animationResizeTime(newFrame)
    }

    override func sendEvent(_ event: NSEvent) {
        if event.type == .leftMouseDown, event.clickCount == 2 {
            onDoubleClick?()
            return
        }
        super.sendEvent(event)
    }
}
