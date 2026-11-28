import XCTest
@testable import KeyVoxPredictiveKeyboard

final class HeldKeyCharactersTests: XCTestCase {
    func testLetterKeysOfferTheirOwnLetterFirstInTheirCase() throws {
        let list = try HeldKeyCharacters.bundled(for: .english)
        let letters = "abcdefghijklmnopqrstuvwxyz"
        let offers = (letters + letters.uppercased()).compactMap { letter in
            list.offer(forKey: String(letter)).map { (String(letter), $0) }
        }
        XCTAssertFalse(offers.isEmpty)
        for (key, offer) in offers {
            XCTAssertEqual(offer.characters.first, key)
            let isUppercase = key == key.uppercased()
            XCTAssertTrue(offer.characters.allSatisfy { ($0 == $0.uppercased()) == isUppercase }, key)
        }
    }

    func testCenteredOfferKeepsItsOrderAndFindsTheKeysOwnText() throws {
        // The centered offer the keyboard shows is the web endings' (`WebEndings`).
        let offer = try XCTUnwrap(try WebEndings.bundled().offer(region: "US", preferredLanguages: ["en-US"], languages: [.english]))
        XCTAssertEqual(offer.held.direction, .centered)
        XCTAssertEqual(offer.held.characters[offer.held.ownIndex], offer.ending)
    }

    func testCenteredOfferWithoutTheKeysOwnTextIsRejected() throws {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try "x\tcentered\ta b c\n".write(to: url, atomically: true, encoding: .utf8)
        defer { try? FileManager.default.removeItem(at: url) }
        XCTAssertThrowsError(try HeldKeyCharacters(contentsOf: url))
    }

    func testLetterKeysOfferNoLetterThatHasAKeyOfItsOwn() throws {
        for language in [TypingLanguage.english, .spanish] {
            let keys = Set(language.letterLayout.rows.flatMap(\.items).compactMap { item -> String? in
                guard case let .character(text) = item else { return nil }
                return text
            })
            let list = try HeldKeyCharacters.bundled(for: language)
            for key in keys.flatMap({ [$0, $0.uppercased()] }) {
                guard let offer = list.offer(forKey: key) else { continue }
                XCTAssertEqual(offer.characters.first, key, "\(language.identifier) \(key)")
                let others = offer.characters.dropFirst().map { $0.lowercased() }
                XCTAssertTrue(keys.isDisjoint(with: others), "\(language.identifier) \(key)")
            }
        }
    }

    func testKeysWithoutAnOfferHaveNone() throws {
        XCTAssertNil(try HeldKeyCharacters.bundled(for: .english).offer(forKey: "q"))
    }
}
