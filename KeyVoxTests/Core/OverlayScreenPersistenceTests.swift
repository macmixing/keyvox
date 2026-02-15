import AppKit
import Testing
@testable import KeyVox

struct OverlayScreenPersistenceTests {
    @Test
    func clampedOriginStaysWithinVisibleFrame() {
        let visibleFrame = CGRect(x: 100, y: 50, width: 400, height: 300)
        let panelSize = CGSize(width: 120, height: 80)

        let clamped = OverlayScreenPersistenceLogic.clampedOrigin(
            origin: NSPoint(x: 50, y: 500),
            panelSize: panelSize,
            visibleFrame: visibleFrame
        )

        #expect(clamped.x == 100)
        #expect(clamped.y == 270)
    }

    @Test
    func decodeOriginPairSupportsDoubleAndNSNumber() {
        let fromDoubles = OverlayScreenPersistenceLogic.decodeOriginPair([12.5, 87.25])
        let fromNumbers = OverlayScreenPersistenceLogic.decodeOriginPair([NSNumber(value: 9.0), NSNumber(value: 4.5)])

        #expect(fromDoubles == NSPoint(x: 12.5, y: 87.25))
        #expect(fromNumbers == NSPoint(x: 9.0, y: 4.5))
    }

    @Test
    func serializedOriginsRoundTripDeterministically() {
        let input: [String: NSPoint] = [
            "display-a": NSPoint(x: 10.5, y: 20.75),
            "display-b": NSPoint(x: 300, y: 40)
        ]

        let serialized = OverlayScreenPersistenceLogic.serializeOrigins(input)
        let deserialized = OverlayScreenPersistenceLogic.deserializeOrigins(serialized)

        #expect(deserialized == input)
    }

    @Test
    func preferredDisplayFallbackDecisionIsDeterministic() {
        #expect(!OverlayScreenPersistenceLogic.shouldUseFallbackDisplay(preferredDisplayKey: nil, preferredScreenExists: false))
        #expect(!OverlayScreenPersistenceLogic.shouldUseFallbackDisplay(preferredDisplayKey: "display-a", preferredScreenExists: true))
        #expect(OverlayScreenPersistenceLogic.shouldUseFallbackDisplay(preferredDisplayKey: "display-a", preferredScreenExists: false))
    }
}
