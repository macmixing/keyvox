import XCTest
#if canImport(CoreGraphics)
import CoreGraphics
#endif
@testable import KeyVoxPredictiveKeyboard

/// Squiggles are found only where they were drawn: of 429 swipes logged on a phone, 21 deliberate
/// squiggle swipes with 22 squiggled keys, 9 of which read as squiggles, and no other key of any of
/// the 429, read at the key centers the measurement fitted from where the logged swipes start and end;
/// the synthetic swipes' squiggles are found, while plain corners and turns are none.
final class SwipeKeySquiggleTests: XCTestCase {
    /// Every key visit of the logged swipes, shuffled, each holding only what the detector reads at
    /// the key, so the fixture holds nothing of what was typed.
    private struct Fixture: Decodable {
        struct Visit: Decodable {
            /// Whether the finger squiggled over the key.
            let squiggled: Bool
            /// How far, in degrees, the key path turns at the key: the angle between the line from
            /// the previous key's center to its center and the line from its center to the next
            /// key's; nil at a swipe's first or last key.
            let pathTurn: Double?
            /// The visit's samples within 1.2 key pitches of the key's center, lined up and read at
            /// 60 a second as the detector reads them, in key pitches from that center, each visit
            /// turned and mirrored at random, which no turn or length the detector measures notices.
            let near: [[Double]]
        }

        let visits: [Visit]
    }

    func testTheLoggedSwipesSquiggleOnlyWhereTheyWereSquiggled() throws {
        let url = try XCTUnwrap(Bundle.module.url(forResource: "Fixtures/swipe_key_squiggles", withExtension: "json"))
        let fixture = try JSONDecoder().decode(Fixture.self, from: Data(contentsOf: url))
        let settings = try SwipeModelSettings.bundled(for: .english)
        let squiggles = try XCTUnwrap(settings.squiggles)
        let sampleRate = try XCTUnwrap(settings.loops).sampleRate
        var found = 0
        for (index, visit) in fixture.visits.enumerated() {
            let squiggled = SwipeKeySquiggle.squiggles(
                near: visit.near.map { CGPoint(x: $0[0], y: $0[1]) },
                pathTurns: (visit.pathTurn ?? 0) > squiggles.sharpTurn,
                pitch: 1,
                sampleRate: sampleRate,
                settings: squiggles
            )
            if visit.squiggled {
                found += squiggled ? 1 : 0
            } else {
                XCTAssertFalse(squiggled, "visit \(index) read a squiggle")
            }
        }
        XCTAssertEqual(fixture.visits.filter(\.squiggled).count, 22)
        XCTAssertEqual(found, 9)
    }

    func testASquiggleOverAKeyIsFoundThere() throws {
        XCTAssertEqual(try squiggledKeys(swiping: "to", squigglingAt: [1]), [false, true])
        XCTAssertEqual(try squiggledKeys(swiping: "son", squigglingAt: [1]), [false, true, false])
        XCTAssertEqual(try squiggledKeys(swiping: "to"), [false, false])
    }

    func testCornersAndTurnsAreNotSquiggles() throws {
        for keys in ["tag", "pal", "zap", "the", "qwerty", "keyboard", "mop", "god", "son"] {
            XCTAssertFalse(try squiggledKeys(swiping: keys).contains(true), keys)
        }
    }

    /// For each of `keys`, whether a swipe through them, squiggling at `squiggles`, squiggles over it.
    private func squiggledKeys(swiping keys: String, squigglingAt squiggles: Set<Int> = []) throws -> [Bool] {
        let map = KeyCenterMap(geometry: TypingLanguage.english.letterLayout.defaultGeometry)
        let settings = try SwipeModelSettings.bundled(for: .english)
        return try XCTUnwrap(SwipeKeySquiggle.squiggledKeys(
            path: SwipePath.through(keys, squigglingAt: squiggles),
            centers: keys.compactMap { map.center(of: $0) },
            pitch: Double(map.pitch.width),
            sampleRate: try XCTUnwrap(settings.loops).sampleRate,
            settings: try XCTUnwrap(settings.squiggles)
        ))
    }
}
