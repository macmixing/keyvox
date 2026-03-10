import CoreGraphics
import Testing
@testable import KeyVox_iOS

struct KeyboardCursorTrackpadSupportTests {
    @Test func shortHoldDoesNotActivateTrackpadMode() {
        var session = KeyboardSpaceTrackpadSession(configuration: KeyboardSpaceTrackpadConfiguration(
            activationHoldDuration: 0.35,
            horizontalStepDistance: 9
        ))

        session.begin(onSpaceKey: true, location: .zero)
        let update = session.update(
            location: CGPoint(x: 2, y: 0),
            isStillOnSpaceKey: true
        )

        #expect(update.activated == false)
        #expect(update.movementDelta == nil)
        #expect(session.phase == .armed)
        #expect(session.end() == false)
    }

    @Test func explicitActivationTransitionsIntoMovementMode() {
        var session = KeyboardSpaceTrackpadSession(configuration: KeyboardSpaceTrackpadConfiguration(
            activationHoldDuration: 0.3,
            horizontalStepDistance: 9
        ))

        session.begin(onSpaceKey: true, location: CGPoint(x: 10, y: 20))
        let activation = session.activate(
            location: CGPoint(x: 10, y: 20)
        )
        let movement = session.update(
            location: CGPoint(x: 24, y: 11),
            isStillOnSpaceKey: true
        )

        #expect(activation == true)
        #expect(movement.activated == false)
        #expect(movement.movementDelta == CGPoint(x: 14, y: -9))
        #expect(session.end() == true)
    }

    @Test func movementBeforeHoldCancelsTrackpadActivation() {
        var session = KeyboardSpaceTrackpadSession(configuration: KeyboardSpaceTrackpadConfiguration(
            activationHoldDuration: 0.35,
            horizontalStepDistance: 9,
            activationMovementTolerance: 8
        ))

        session.begin(onSpaceKey: true, location: .zero)

        let earlyDrag = session.update(
            location: CGPoint(x: 12, y: 0),
            isStillOnSpaceKey: true
        )
        let laterHold = session.update(
            location: CGPoint(x: 12, y: 0),
            isStillOnSpaceKey: true
        )

        #expect(earlyDrag.activated == false)
        #expect(earlyDrag.movementDelta == nil)
        #expect(laterHold.activated == false)
        #expect(laterHold.movementDelta == nil)
        #expect(session.phase == .inactive)
        #expect(session.end() == false)
    }

    @Test func activationFailsAfterArmingIsCancelled() {
        var session = KeyboardSpaceTrackpadSession(configuration: KeyboardSpaceTrackpadConfiguration(
            activationHoldDuration: 0.35,
            horizontalStepDistance: 9,
            activationMovementTolerance: 8
        ))

        session.begin(onSpaceKey: true, location: .zero)
        _ = session.update(
            location: CGPoint(x: 12, y: 0),
            isStillOnSpaceKey: true
        )

        #expect(session.activate(location: CGPoint(x: 12, y: 0)) == false)
        #expect(session.phase == .inactive)
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
