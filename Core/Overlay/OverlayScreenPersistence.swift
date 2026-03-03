import AppKit
import Foundation

final class OverlayScreenPersistence {
    private let defaultVerticalOffset: CGFloat
    private let panelEdgeInset: CGFloat
    private var isUsingFallbackDisplay = false
    private var hasLoadedPreferredDisplayKey = false
    private var preferredDisplayKeyCache: String?
    private var hasLoadedOriginsByDisplay = false
    // Lazy cache avoids repeated UserDefaults decoding on hot show/hide/move paths.
    private var originsByDisplayCache: [String: NSPoint] = [:]

    init(defaultVerticalOffset: CGFloat = 50, panelEdgeInset: CGFloat = 0) {
        self.defaultVerticalOffset = defaultVerticalOffset
        self.panelEdgeInset = max(0, panelEdgeInset)
    }

    func resolvedOriginForShow(panel: NSPanel) -> NSPoint {
        // Prefer the persisted display when still connected; otherwise keep continuity on current fallback display.
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

        isUsingFallbackDisplay = OverlayScreenPersistenceLogic.shouldUseFallbackDisplay(
            preferredDisplayKey: preferredKey,
            preferredScreenExists: false
        )

        if let fallbackKey = displayKey(for: fallbackScreen),
           let origin = savedOrigin(for: fallbackKey) {
            return clampedOrigin(origin, for: panel, on: fallbackScreen)
        }

        return clampedOrigin(defaultOrigin(for: panel, on: fallbackScreen), for: panel, on: fallbackScreen)
    }

    func persistPanelLocation(_ panel: NSPanel) {
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

    func handleScreenParametersChanged(for panel: NSPanel, clampOriginThreshold: CGFloat) {
        guard let preferredKey = loadPreferredDisplayKey() else {
            if panel.isVisible { clampPanelToVisibleBounds(panel, threshold: clampOriginThreshold) }
            return
        }

        if let preferredScreen = screen(forDisplayKey: preferredKey) {
            // If a previously missing preferred display returns, move back to its saved/default origin once.
            if isUsingFallbackDisplay, panel.isVisible {
                let origin = savedOrigin(for: preferredKey) ?? defaultOrigin(for: panel, on: preferredScreen)
                panel.setFrameOrigin(clampedOrigin(origin, for: panel, on: preferredScreen))
                isUsingFallbackDisplay = false
            } else if panel.isVisible {
                clampPanelToVisibleBounds(panel, threshold: clampOriginThreshold)
            }
            return
        }

        isUsingFallbackDisplay = true
        if panel.isVisible {
            clampPanelToVisibleBounds(panel, threshold: clampOriginThreshold)
        }
    }

    func defaultOrigin(for panel: NSPanel) -> NSPoint {
        guard let screen = panel.screen ?? NSScreen.main ?? NSScreen.screens.first else {
            return panel.frame.origin
        }
        return defaultOrigin(for: panel, on: screen)
    }

    func screenContaining(point: NSPoint) -> NSScreen? {
        NSScreen.screens.first(where: { $0.visibleFrame.contains(point) }) ?? NSScreen.main
    }

    private func clampPanelToVisibleBounds(_ panel: NSPanel, threshold: CGFloat) {
        let center = NSPoint(x: panel.frame.midX, y: panel.frame.midY)
        guard let screen = screenContaining(point: center) ?? panel.screen ?? NSScreen.main ?? NSScreen.screens.first else {
            return
        }

        let clamped = clampedOrigin(panel.frame.origin, for: panel, on: screen)
        if abs(clamped.x - panel.frame.origin.x) > threshold || abs(clamped.y - panel.frame.origin.y) > threshold {
            panel.setFrameOrigin(clamped)
        }
    }

    private func defaultOrigin(for panel: NSPanel, on screen: NSScreen) -> NSPoint {
        let rect = screen.visibleFrame
        return NSPoint(
            x: rect.midX - (panel.frame.width / 2),
            y: rect.minY + defaultVerticalOffset
        )
    }

    private func clampedOrigin(_ origin: NSPoint, for panel: NSPanel, on screen: NSScreen) -> NSPoint {
        OverlayScreenPersistenceLogic.clampedOrigin(
            origin: origin,
            panelSize: panel.frame.size,
            visibleFrame: screen.visibleFrame,
            edgeInset: panelEdgeInset
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
        let serialized = OverlayScreenPersistenceLogic.serializeOrigins(origins)
        UserDefaults.standard.set(serialized, forKey: UserDefaultsKeys.recordingOverlayOriginsByDisplay)
    }

    private func loadOriginsByDisplay() -> [String: NSPoint] {
        if hasLoadedOriginsByDisplay {
            return originsByDisplayCache
        }

        let defaults = UserDefaults.standard
        var origins = [String: NSPoint]()
        if let raw = defaults.dictionary(forKey: UserDefaultsKeys.recordingOverlayOriginsByDisplay) {
            origins = OverlayScreenPersistenceLogic.deserializeOrigins(raw)
        }

        if origins.isEmpty,
           let legacyOrigin = loadLegacySavedOrigin(),
           let screen = screenContaining(point: legacyOrigin) ?? NSScreen.main ?? NSScreen.screens.first,
           let displayKey = displayKey(for: screen) {
            // One-time migration from legacy single-origin storage into per-display storage.
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
        OverlayScreenPersistenceLogic.decodeOriginPair(
            UserDefaults.standard.array(forKey: UserDefaultsKeys.recordingOverlayOrigin)
        )
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
}

enum OverlayScreenPersistenceLogic {
    static func clampedOrigin(
        origin: NSPoint,
        panelSize: CGSize,
        visibleFrame: CGRect,
        edgeInset: CGFloat = 0
    ) -> NSPoint {
        let expandedFrame = visibleFrame.insetBy(dx: -max(0, edgeInset), dy: -max(0, edgeInset))
        let maxX = max(expandedFrame.minX, expandedFrame.maxX - panelSize.width)
        let maxY = max(expandedFrame.minY, expandedFrame.maxY - panelSize.height)
        return NSPoint(
            x: min(max(origin.x, expandedFrame.minX), maxX),
            y: min(max(origin.y, expandedFrame.minY), maxY)
        )
    }

    static func decodeOriginPair(_ rawValue: Any?) -> NSPoint? {
        guard let rawValue else { return nil }

        if let doubles = rawValue as? [Double], doubles.count == 2 {
            return NSPoint(x: doubles[0], y: doubles[1])
        }

        if let numbers = rawValue as? [NSNumber], numbers.count == 2 {
            return NSPoint(x: numbers[0].doubleValue, y: numbers[1].doubleValue)
        }

        if let values = rawValue as? [Any], values.count == 2,
           let x = numericValue(values[0]),
           let y = numericValue(values[1]) {
            return NSPoint(x: x, y: y)
        }

        return nil
    }

    static func serializeOrigins(_ origins: [String: NSPoint]) -> [String: [Double]] {
        origins.mapValues { [Double($0.x), Double($0.y)] }
    }

    static func deserializeOrigins(_ raw: [String: Any]) -> [String: NSPoint] {
        var origins = [String: NSPoint]()
        for (key, value) in raw {
            if let origin = decodeOriginPair(value) {
                origins[key] = origin
            }
        }
        return origins
    }

    static func shouldUseFallbackDisplay(preferredDisplayKey: String?, preferredScreenExists: Bool) -> Bool {
        preferredDisplayKey != nil && !preferredScreenExists
    }

    private static func numericValue(_ value: Any) -> Double? {
        if let number = value as? NSNumber {
            return number.doubleValue
        }
        if let double = value as? Double {
            return double
        }
        return nil
    }
}
