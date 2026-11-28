import XCTest
@testable import KeyVoxPredictiveKeyboard

/// The web endings Apple's iOS 27.2 keyboard showed in a web address field on the simulator, by
/// device region, with the device's languages English (US) then German (US): the key's ending, and
/// the popup left to right.
final class WebEndingsTests: XCTestCase {
    private let endings: WebEndings = {
        do { return try WebEndings.bundled() } catch { fatalError("the bundled web endings did not load: \(error)") }
    }()
    private let deviceLanguages = ["en-US", "de-US"]

    private func shown(_ region: String, _ languages: [TypingLanguage]) throws -> (String, [String]) {
        let offer = try XCTUnwrap(endings.offer(region: region, preferredLanguages: deviceLanguages, languages: languages))
        XCTAssertEqual(offer.held.characters[offer.held.ownIndex], offer.ending)
        return (offer.ending, offer.held.characters)
    }

    func testTheKeyAndItsPopupFollowTheDeviceRegion() throws {
        let measured: [(String, [TypingLanguage], String, [String])] = [
            ("US", [.german], ".com", [".eu", ".de", ".us", ".edu", ".com", ".net", ".org"]),
            ("DE", [.german], ".de", [".net", ".eu", ".org", ".de", ".com", ".edu"]),
            ("FR", [.german], ".fr", [".de", ".net", ".eu", ".org", ".fr", ".com", ".edu"]),
            ("CH", [.german], ".com", [".de", ".net", ".eu", ".org", ".com", ".ch", ".edu"]),
            ("DE", [.english, .german], ".de", [".us", ".net", ".eu", ".org", ".de", ".com", ".edu"]),
            ("US", [.english, .german], ".com", [".eu", ".de", ".us", ".edu", ".com", ".net", ".org"]),
        ]
        for (region, languages, ending, popup) in measured {
            let (key, characters) = try shown(region, languages)
            XCTAssertEqual(key, ending, region)
            XCTAssertEqual(characters, popup, region)
        }
    }

    func testARegionsLongerListKeepsTwoEndingsRightOfTheKey() throws {
        // Apple's keyboard drew the eighth ending, ".de", in a second row; the order is the same.
        let (key, characters) = try shown("GB", [.german])
        XCTAssertEqual(key, ".co.uk")
        XCTAssertEqual(characters, [".de", ".net", ".uk", ".eu", ".edu", ".ie", ".co.uk", ".com", ".org"])
    }

    func testEnglishOnAUSDeviceOffersTheEndingsItAlwaysHas() throws {
        let offer = try XCTUnwrap(endings.offer(region: "US", preferredLanguages: ["en-US"], languages: [.english]))
        XCTAssertEqual(offer.ending, ".com")
        XCTAssertEqual(offer.held.characters, [".us", ".edu", ".com", ".net", ".org"])
    }

    func testLatinAmericanSpanishFollowsTheRegionAsApplesLatinAmericanKeyboardDid() throws {
        // Apple's Spanish (Latin America) keyboard alone, device language English (US)
        // (`~/KeyVoxLanguageData/apple-languages/runs/sim419-url-es_419-<region>`).
        let latinAmerican = try TypingLanguage.bundled(identifier: "es-419")
        let measured: [(String, [String])] = [
            ("US", [".gob", ".us", ".edu", ".com", ".net", ".org"]),
            ("MX", [".net", ".gob", ".org", ".com", ".mx", ".edu"]),
            ("AR", [".gob", ".net", ".org", ".com", ".ar", ".edu"]),
        ]
        for (region, popup) in measured {
            let offer = try XCTUnwrap(endings.offer(region: region, preferredLanguages: ["en-US"], languages: [latinAmerican]))
            XCTAssertEqual(offer.ending, ".com", region)
            XCTAssertEqual(offer.held.characters, popup, region)
        }
    }

    func testWithoutARegionTheKeyboardsLanguageGivesTheEndings() throws {
        let offer = try XCTUnwrap(endings.offer(region: nil, preferredLanguages: [], languages: [.german]))
        XCTAssertEqual(offer.ending, ".de")
    }
}
