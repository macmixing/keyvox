import AppKit
import XCTest
@testable import KeyVox

final class OverlayScreenPersistenceTests: XCTestCase {
    func testClampedOriginStaysWithinVisibleFrame() {
        let visibleFrame = CGRect(x: 100, y: 50, width: 400, height: 300)
        let panelSize = CGSize(width: 120, height: 80)

        let clamped = OverlayScreenPersistenceLogic.clampedOrigin(
            origin: NSPoint(x: 50, y: 500),
            panelSize: panelSize,
            visibleFrame: visibleFrame
        )

        XCTAssertTrue(clamped.x == 100)
        XCTAssertTrue(clamped.y == 270)
    }

    func testDecodeOriginPairSupportsDoubleAndNSNumber() {
        let fromDoubles = OverlayScreenPersistenceLogic.decodeOriginPair([12.5, 87.25])
        let fromNumbers = OverlayScreenPersistenceLogic.decodeOriginPair([NSNumber(value: 9.0), NSNumber(value: 4.5)])

        XCTAssertTrue(fromDoubles == NSPoint(x: 12.5, y: 87.25))
        XCTAssertTrue(fromNumbers == NSPoint(x: 9.0, y: 4.5))
    }

    func testSerializedOriginsRoundTripDeterministically() {
        let input: [String: NSPoint] = [
            "display-a": NSPoint(x: 10.5, y: 20.75),
            "display-b": NSPoint(x: 300, y: 40)
        ]

        let serialized = OverlayScreenPersistenceLogic.serializeOrigins(input)
        let deserialized = OverlayScreenPersistenceLogic.deserializeOrigins(serialized)

        XCTAssertTrue(deserialized == input)
    }

    func testPreferredDisplayFallbackDecisionIsDeterministic() {
        XCTAssertTrue(!OverlayScreenPersistenceLogic.shouldUseFallbackDisplay(preferredDisplayKey: nil, preferredScreenExists: false))
        XCTAssertTrue(!OverlayScreenPersistenceLogic.shouldUseFallbackDisplay(preferredDisplayKey: "display-a", preferredScreenExists: true))
        XCTAssertTrue(OverlayScreenPersistenceLogic.shouldUseFallbackDisplay(preferredDisplayKey: "display-a", preferredScreenExists: false))
    }
}
