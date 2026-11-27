import XCTest
@testable import KeyVoxPredictiveKeyboard

/// The Swift swipe decoder against the swipe model tools' NumPy reference
/// (`Tools/KeyVoxSwipeModel/exported_model.py`, `beam_search.c`, `scoring.py`) on a fixed set of
/// swipe.futo.org validation swipes: the same best word for every swipe, and the same scores
/// for the reference's ten best within half-precision rounding.
final class SwipeModelParityTests: XCTestCase {
    private struct Fixture: Decodable {
        struct Swipe: Decodable {
            let word: String
            let xy: [Float]
            /// The reference's ten best forms with their scores.
            let top: [[ScoredForm]]
        }

        enum ScoredForm: Decodable {
            case form(String)
            case score(Double)

            init(from decoder: Decoder) throws {
                let container = try decoder.singleValueContainer()
                if let form = try? container.decode(String.self) {
                    self = .form(form)
                } else {
                    self = .score(try container.decode(Double.self))
                }
            }
        }

        let keyCenters: [[Float]]
        let letters: String
        let swipes: [Swipe]
    }

    /// Half precision keeps about three significant digits.
    private static let relativeTolerance = 1e-3

    func testSwiftDecodingMatchesTheReferenceOnValidationSwipes() throws {
        let url = try XCTUnwrap(Bundle.module.url(forResource: "Fixtures/swipe_parity", withExtension: "json"))
        let fixture = try JSONDecoder().decode(Fixture.self, from: Data(contentsOf: url))
        let decoder = try SwipeWordDecoder(language: .english)
        XCTAssertEqual(fixture.letters, decoder.settings.letters)
        let centers = fixture.keyCenters.map { (x: $0[0], y: $0[1]) }
        var largestDifference = 0.0
        for (number, swipe) in fixture.swipes.enumerated() {
            let reference = swipe.top.compactMap { pair -> (form: String, score: Double)? in
                guard case let .form(form) = pair[0], case let .score(score) = pair[1] else { return nil }
                return (form, score)
            }
            let candidates = decoder.candidates(
                emissions: decoder.emissions(forResampled: swipe.xy, keyCenters: centers),
                personal: nil,
                contextLift: nil,
                hasWordsBefore: false,
                doublingKeys: nil
            )
            var scoreByForm: [String: Double] = [:]
            var forms: [String] = []
            for candidate in candidates {
                let form = SwipeLetterForm.form(of: candidate.spelling)
                if scoreByForm[form] == nil {
                    scoreByForm[form] = candidate.score
                    forms.append(form)
                }
            }
            XCTAssertEqual(forms.first, reference.first?.form, "swipe \(number) (\(swipe.word))")
            for entry in reference {
                guard let score = scoreByForm[entry.form] else {
                    XCTFail("swipe \(number) (\(swipe.word)) lacks \(entry.form)")
                    continue
                }
                let difference = abs(score - entry.score)
                largestDifference = max(largestDifference, difference / max(1, abs(entry.score)))
                XCTAssertLessThanOrEqual(
                    difference, Self.relativeTolerance * max(1, abs(entry.score)),
                    "swipe \(number) (\(swipe.word)) \(entry.form)"
                )
            }
        }
        print("largest relative score difference: \(largestDifference)")
    }
}
