import CoreGraphics
import XCTest
@testable import KeyVox

final class AudioIndicatorDriverTests: XCTestCase {
    func testSmoothingAdvancesTowardTargetWithoutOvershoot() {
        let driver = AudioIndicatorDriver()
        driver.setPhase(.listening)

        driver.advance(to: 0, sample: makeSample(level: 1.0, signalState: .active, timestamp: 0))
        let firstLevel = driver.timelineState.displayedLevel

        driver.advance(to: 0.05, sample: makeSample(level: 1.0, signalState: .active, timestamp: 0.05))
        let secondLevel = driver.timelineState.displayedLevel

        XCTAssertGreaterThan(firstLevel, 0)
        XCTAssertLessThanOrEqual(firstLevel, 1)
        XCTAssertGreaterThan(secondLevel, firstLevel)
        XCTAssertLessThanOrEqual(secondLevel, 1)
    }

    func testLeavingListeningResetsToInactive() {
        let driver = AudioIndicatorDriver()
        driver.setPhase(.listening)
        driver.advance(to: 0, sample: makeSample(level: 1.0, signalState: .active, timestamp: 0))
        let levelWhileListening = driver.timelineState.displayedLevel

        driver.setPhase(.processing)
        driver.advance(to: 0.05, sample: makeSample(level: 1.0, signalState: .active, timestamp: 0.05))

        XCTAssertEqual(driver.timelineState.signalState, .inactive)
        XCTAssertLessThan(driver.timelineState.displayedLevel, levelWhileListening)
    }

    func testStaleSampleResolvesToInactive() {
        let driver = AudioIndicatorDriver()
        driver.setPhase(.listening)

        driver.advance(to: 1.0, sample: makeSample(level: 0.8, signalState: .active, timestamp: 0))

        XCTAssertEqual(driver.timelineState.signalState, .inactive)
        XCTAssertEqual(driver.timelineState.displayedLevel, 0, accuracy: 0.0001)
    }

    func testProcessingPhaseAdvancesIndependentlyOfLiveInput() {
        let driver = AudioIndicatorDriver()
        driver.setPhase(.processing)
        let initialPhase = driver.timelineState.processingPhase

        driver.advance(to: 0.05, sample: nil)

        XCTAssertGreaterThan(driver.timelineState.processingPhase, initialPhase)
        XCTAssertEqual(driver.timelineState.signalState, .inactive)
    }

    func testLowActivityPhaseAdvancesIndependentlyOfActiveSignalPeaks() {
        let driver = AudioIndicatorDriver()
        driver.setPhase(.listening)
        let initialPhase = driver.timelineState.lowActivityPhase

        driver.advance(to: 0.05, sample: makeSample(level: 0.9, signalState: .active, timestamp: 0.05))

        XCTAssertGreaterThan(driver.timelineState.lowActivityPhase, initialPhase)
    }

    private func makeSample(level: CGFloat, signalState: AudioIndicatorSignalState, timestamp: TimeInterval) -> AudioIndicatorSample {
        AudioIndicatorSample(level: level, signalState: signalState, timestamp: timestamp)
    }
}
