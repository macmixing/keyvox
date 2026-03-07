import XCTest
@testable import KeyVoxCore

final class AudioPostProcessingTests: XCTestCase {
    func testRemoveInternalGapsPreservesTrailingPartialWindow() {
        let speechWindow = Array(repeating: Float(0.2), count: 1_600)
        let removableGapWindowCount = 17
        let gap = Array(repeating: Float(0.0), count: removableGapWindowCount * 1_600)
        let tail = Array(repeating: Float(0.2), count: 5)
        let samples = speechWindow + gap + speechWindow + tail

        let processed = AudioPostProcessing.removeInternalGaps(
            from: samples,
            gapRemovalRMSThreshold: 0.01
        )

        let expected = speechWindow
            + Array(repeating: Float(0.0), count: (removableGapWindowCount - 1) * 1_600)
            + speechWindow
            + tail

        XCTAssertEqual(processed.count, samples.count - 1_600)
        XCTAssertEqual(processed, expected)
        XCTAssertEqual(Array(processed.suffix(5)), tail)
    }
}
