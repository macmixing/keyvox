import CoreGraphics
import Testing
@testable import KeyVox_iOS

struct KeyboardCursorTrackpadSupportTests {
    @Test func shortHoldDoesNotActivateTrackpadMode() {
        var session = KeyboardSpaceTrackpadSession(configuration: KeyboardSpaceTrackpadConfiguration(
            activationHoldDuration: 0.35,
            horizontalStepDistance: 9
        ))

        session.begin(onSpaceKey: true, location: .zero, timestamp: 10)
        let update = session.update(
            location: CGPoint(x: 2, y: 0),
            timestamp: 10.2,
            isStillOnSpaceKey: true
        )

        #expect(update.activated == false)
        #expect(update.movementDelta == nil)
        #expect(session.phase == .armed)
        #expect(session.end() == false)
    }

    @Test func holdActivationTransitionsIntoMovementMode() {
        var session = KeyboardSpaceTrackpadSession(configuration: KeyboardSpaceTrackpadConfiguration(
            activationHoldDuration: 0.3,
            horizontalStepDistance: 9
        ))

        session.begin(onSpaceKey: true, location: CGPoint(x: 10, y: 20), timestamp: 1)
        let activation = session.update(
            location: CGPoint(x: 10, y: 20),
            timestamp: 1.35,
            isStillOnSpaceKey: true
        )
        let movement = session.update(
            location: CGPoint(x: 24, y: 11),
            timestamp: 1.4,
            isStillOnSpaceKey: true
        )

        #expect(activation.activated == true)
        #expect(activation.movementDelta == nil)
        #expect(movement.activated == false)
        #expect(movement.movementDelta == CGPoint(x: 14, y: -9))
        #expect(session.end() == true)
    }

    @Test func accumulatorRequiresThresholdAndEmitsRepeatedHorizontalSteps() {
        var accumulator = KeyboardCursorTrackpadAccumulator(configuration: KeyboardSpaceTrackpadConfiguration(
            activationHoldDuration: 0.35,
            horizontalStepDistance: 9
        ))

        #expect(accumulator.consume(delta: CGPoint(x: 8, y: 0)) == 0)
        #expect(accumulator.consume(delta: CGPoint(x: 10, y: 0)) == 2)
        #expect(accumulator.consume(delta: CGPoint(x: -27, y: 0)) == -3)
    }

    @Test func interactorAppliesHorizontalMovement() {
        var appliedOffsets: [Int] = []
        var interactor = KeyboardCursorTrackpadInteractor(configuration: KeyboardSpaceTrackpadConfiguration(
            activationHoldDuration: 0.35,
            horizontalStepDistance: 9
        ))

        interactor.begin()
        interactor.handleMovement(delta: CGPoint(x: 21, y: 30)) { offset in
            appliedOffsets.append(offset)
        }

        #expect(appliedOffsets == [2])
    }
}
