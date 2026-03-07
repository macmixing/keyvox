import XCTest
@testable import KeyVoxCore

final class AudioPostProcessingTests: XCTestCase {
    func testRemoveInternalGapsPreservesTrailingPartialWindow() {
        let samples = Array(repeating: Float(0.2), count: 1_605)

        let processed = AudioPostProcessing.removeInternalGaps(
            from: samples,
            gapRemovalRMSThreshold: 0.01
        )

        XCTAssertEqual(processed.count, samples.count)
        XCTAssertEqual(processed, samples)
    }
}
