import XCTest
#if canImport(CoreGraphics)
import CoreGraphics
#endif
@testable import KeyVoxPredictiveKeyboard

/// Loops are found as they were measured: 300 swipe.futo.org validation swipes, two thirds of
/// words with a doubled letter, with each key's visit and loop as the measurement finds them, on
/// the fixture's clock and on one reading as a phone's does days after it starts.
final class SwipeKeyLoopParityTests: XCTestCase {
    private struct Fixture: Decodable {
        struct Swipe: Decodable {
            struct Key: Decodable {
                let visit: [Int]
                let hasLoop: Bool
            }

            let word: String
            let pitch: Double
            let centers: [[Double]]
            /// Milliseconds since the first sample, then x and y in points.
            let points: [[Double]]
            let keys: [Key]
        }

        let swipes: [Swipe]
    }

    func testEveryKeysVisitAndLoopMatchTheMeasurement() throws {
        let url = try XCTUnwrap(Bundle.module.url(forResource: "Fixtures/swipe_key_loops", withExtension: "json"))
        let fixture = try JSONDecoder().decode(Fixture.self, from: Data(contentsOf: url))
        let settings = try XCTUnwrap(SwipeModelSettings.bundled(for: .english).loops)
        var keys = 0
        var loops = 0
        for (swipe, clock) in fixture.swipes.flatMap({ swipe in [(swipe, 0.0), (swipe, 787_839.905_422_958)] }) {
            let path = swipe.points.map {
                SwipeTouchSample(location: CGPoint(x: $0[1], y: $0[2]), timestamp: clock + $0[0] / 1000)
            }
            let centers = swipe.centers.map { CGPoint(x: $0[0], y: $0[1]) }
            let visits = try XCTUnwrap(SwipeKeyVisits(
                path: path, centers: centers, pitch: swipe.pitch, sampleRate: settings.sampleRate
            ), swipe.word)
            for (index, expected) in swipe.keys.enumerated() {
                XCTAssertEqual(visits.visits[index], expected.visit[0]...expected.visit[1], "\(swipe.word) key \(index)")
                let looped = SwipeKeyLoop.loops(
                    points: visits.points,
                    range: visits.visits[index],
                    center: centers[index],
                    pitch: swipe.pitch,
                    settings: settings
                )
                XCTAssertEqual(looped, expected.hasLoop, "\(swipe.word) key \(index)")
                keys += 1
                loops += expected.hasLoop ? 1 : 0
            }
        }
        XCTAssertGreaterThan(keys, 2_000)
        XCTAssertGreaterThan(loops, 10, "the fixture holds swipes that loop")
    }
}
