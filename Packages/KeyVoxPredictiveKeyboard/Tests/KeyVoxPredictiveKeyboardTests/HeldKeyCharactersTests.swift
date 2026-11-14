import XCTest
@testable import KeyVoxPredictiveKeyboard

final class HeldKeyCharactersTests: XCTestCase {
    func testLetterKeysOfferTheirOwnLetterFirstInTheirCase() throws {
        let list = try HeldKeyCharacters.bundled()
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
        let list = try HeldKeyCharacters.bundled()
        let offers = list.offersByKey.filter { $0.value.direction == .centered }
        XCTAssertFalse(offers.isEmpty)
        for (key, offer) in offers {
            XCTAssertEqual(offer.characters[offer.ownIndex], key)
        }
    }

    func testCenteredOfferWithoutTheKeysOwnTextIsRejected() throws {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try "x\tcentered\ta b c\n".write(to: url, atomically: true, encoding: .utf8)
        defer { try? FileManager.default.removeItem(at: url) }
        XCTAssertThrowsError(try HeldKeyCharacters(contentsOf: url))
    }

    func testKeysWithoutAnOfferHaveNone() throws {
        XCTAssertNil(try HeldKeyCharacters.bundled().offer(forKey: "q"))
    }
}
