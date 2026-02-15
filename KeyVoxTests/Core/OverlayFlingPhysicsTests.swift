import AppKit
import CoreGraphics
import XCTest
@testable import KeyVox

final class OverlayFlingPhysicsTests: XCTestCase {
    func testRightwardVelocityHitsRightEdgeFirst() {
        let bounds = CGRect(x: 0, y: 0, width: 100, height: 100)
        let origin = NSPoint(x: 20, y: 25)
        let velocity = CGVector(dx: 200, dy: 10)

        let impact = OverlayFlingPhysics.firstImpactResult(from: origin, velocity: velocity, bounds: bounds)

        XCTAssertTrue(impact?.edge == .right)
        XCTAssertTrue(abs((impact?.originAtImpact.x ?? 0) - bounds.maxX) < 0.001)
    }

    func testDiagonalVelocityUsesSmallestPositiveImpactTime() {
        let bounds = CGRect(x: 0, y: 0, width: 100, height: 100)
        let origin = NSPoint(x: 50, y: 50)
        let velocity = CGVector(dx: -100, dy: 200)

        let impact = OverlayFlingPhysics.firstImpactResult(from: origin, velocity: velocity, bounds: bounds)

        XCTAssertTrue(impact?.edge == .top)
    }

    func testNearZeroVelocityHasNoImpact() {
        let bounds = CGRect(x: 0, y: 0, width: 100, height: 100)
        let origin = NSPoint(x: 50, y: 50)

        let impact = OverlayFlingPhysics.firstImpactResult(
            from: origin,
            velocity: CGVector(dx: 0.00001, dy: -0.00001),
            bounds: bounds
        )

        XCTAssertTrue(impact == nil)
    }

    func testReflectionNormalizesAgainstEachEdgeNormal() {
        assertReflected(
            velocity: CGVector(dx: -2, dy: 1),
            normal: FlingImpactEdge.left.normal,
            expected: CGVector(dx: 2, dy: 1)
        )
        assertReflected(
            velocity: CGVector(dx: 2, dy: 1),
            normal: FlingImpactEdge.right.normal,
            expected: CGVector(dx: -2, dy: 1)
        )
        assertReflected(
            velocity: CGVector(dx: 1, dy: -3),
            normal: FlingImpactEdge.bottom.normal,
            expected: CGVector(dx: 1, dy: 3)
        )
        assertReflected(
            velocity: CGVector(dx: 1, dy: 3),
            normal: FlingImpactEdge.top.normal,
            expected: CGVector(dx: 1, dy: -3)
        )
    }

    func testTravelDurationClampsToMinAndMax() {
        let minDuration = OverlayFlingPhysics.travelDuration(
            distance: 100,
            speed: 10_000,
            minDuration: 0.12,
            maxDuration: 0.30
        )
        let maxDuration = OverlayFlingPhysics.travelDuration(
            distance: 100,
            speed: 10,
            minDuration: 0.12,
            maxDuration: 0.30
        )

        XCTAssertTrue(abs(minDuration - 0.12) < 0.0001)
        XCTAssertTrue(abs(maxDuration - 0.30) < 0.0001)
    }

    private func assertReflected(velocity: CGVector, normal: CGVector, expected: CGVector) {
        let reflected = OverlayFlingPhysics.reflectedDirection(velocity: velocity, normal: normal)
        let expectedLength = hypot(expected.dx, expected.dy)
        let expectedUnit = CGVector(dx: expected.dx / expectedLength, dy: expected.dy / expectedLength)

        XCTAssertTrue(abs(reflected.dx - expectedUnit.dx) < 0.0001)
        XCTAssertTrue(abs(reflected.dy - expectedUnit.dy) < 0.0001)
    }
}
