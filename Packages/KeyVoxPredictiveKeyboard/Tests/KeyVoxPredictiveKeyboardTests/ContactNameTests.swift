import XCTest
@testable import KeyVoxPredictiveKeyboard

/// Contact names are spelled with their capitals and completed on space, while a contact
/// word that is also an everyday word stays as typed, and one that is a dictionary word written
/// without its apostrophe is corrected as if no contact had it.
final class ContactNameTests: XCTestCase {
    private var computer: PredictionComputer!

    override func setUpWithError() throws {
        computer = PredictionComputer(engine: try EnglishPredictiveEngine())
        try computer.updateVocabulary(PersonalVocabulary(
            words: [],
            knownNames: ["Ahleah Old", "Dont Answer"],
            textReplacements: []
        ))
    }

    func testContactNameTakesItsCapitals() throws {
        XCTAssertEqual(try autocorrection(typing: "hi ahleah"), "Ahleah")
    }

    func testPartlyTypedContactNameCompletesOnSpace() throws {
        XCTAssertEqual(try autocorrection(typing: "hi ahle"), "Ahleah")
    }

    func testEverydayContactWordStaysAsTyped() throws {
        XCTAssertNil(try autocorrection(typing: "my old"))
    }

    func testContactWordMissingItsApostropheIsCorrectedAsWithoutTheContact() throws {
        let withoutContacts = PredictionComputer(engine: try EnglishPredictiveEngine())
        let request = PredictiveTypingSession().request(textBeforeCursor: "I dont")
        XCTAssertNotNil(try withoutContacts.compute(request).autocorrection)
        XCTAssertEqual(try autocorrection(typing: "I dont"), try withoutContacts.compute(request).autocorrection)
    }

    private func autocorrection(typing text: String) throws -> String? {
        let request = PredictiveTypingSession().request(textBeforeCursor: text)
        return try computer.compute(request).autocorrection
    }
}
