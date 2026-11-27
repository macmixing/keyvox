import CoreGraphics
import XCTest
@testable import KeyVoxPredictiveKeyboard

extension TypingLanguage {
    /// The bundled German language.
    static let german: TypingLanguage = {
        do {
            return try TypingLanguage.bundled(identifier: "de")
        } catch {
            fatalError("the bundled German typing language did not load: \(error)")
        }
    }()
}

/// German as Apple's iOS 27.2 German (Germany) keyboard types it, measured key by key on an
/// iPhone and a simulator (`~/KeyVoxLanguageData/apple-languages`).
final class GermanTypingLanguageTests: XCTestCase {
    func testGermanShowsQWERTZGermanAndOffersApplesOtherLayoutsInOrder() {
        let german = TypingLanguage.german
        XCTAssertEqual(german.letterLayout.identifier, "QWERTZ-German")
        XCTAssertEqual(german.alternativeLetterLayouts, ["QWERTZ", "QWERTY", "AZERTY"])
    }

    func testEditsTryEveryLetterGermanTypes() {
        let letters = Set(TypingLanguage.german.editLetters)
        for letter in "abcdefghijklmnopqrstuvwxyzäöüß" {
            XCTAssertTrue(letters.contains(letter), String(letter))
        }
        let keys = TypingLanguage.german.letterLayout.rows.flatMap(\.items).compactMap { item -> String? in
            if case let .character(character) = item { return character }
            return nil
        }
        XCTAssertEqual(keys.count, 29)
        XCTAssertTrue(Set(keys.joined()).isSubset(of: letters))
    }

    func testQuoteKeysTypeGermanMarks() {
        let quotes = TypingLanguage.german.quotes
        XCTAssertEqual(quotes.text(for: "\"", after: nil), "„")
        XCTAssertEqual(quotes.text(for: "\"", after: "Ja "), "„")
        XCTAssertEqual(quotes.text(for: "\"", after: "„Ja"), "“")
        XCTAssertEqual(quotes.text(for: "\"", after: "„"), "“")
        XCTAssertEqual(quotes.text(for: SmartQuotes.apostrophe, after: "Ja "), "‚")
        // Apple's German keyboard types its closing single mark as the apostrophe: "Geht‘s".
        XCTAssertEqual(quotes.text(for: SmartQuotes.apostrophe, after: "Geht"), "‘")
    }

    func testTheTypedApostropheJoinsAGermanWord() {
        let rules = TypingLanguage.german.textRules
        let context = TypingTextContext(textBeforeCursor: "Wie geht‘s", rules: rules)
        XCTAssertEqual(context.currentWord, "geht‘s")
        XCTAssertEqual(context.previousWords, ["Wie"])
        XCTAssertEqual(rules.straightApostrophes(in: "geht‘s"), "geht's")
        // English keeps reading "‘" as an opening quotation mark.
        XCTAssertEqual(TypingTextContext(textBeforeCursor: "Wie geht‘s").currentWord, "s")
    }

    func testAPeriodAfterADigitWritesAnOrdinalNumber() {
        let rules = TypingLanguage.german.textRules
        // Apple's German keyboard leaves shift off after "Am 3. " and suggests lowercase words.
        XCTAssertFalse(TypingTextContext.startsSentence(after: "Am 3. ", rules: rules))
        XCTAssertFalse(TypingLanguage.german.startsSentence(after: "Am 3. "))
        XCTAssertTrue(TypingLanguage.english.startsSentence(after: "Am 3. "))
        XCTAssertEqual(TypingTextContext(textBeforeCursor: "Am 3. ", rules: rules).previousWords, ["Am"])
        XCTAssertNil(SentenceEnding(before: "Am 3. ", rules: rules))
        XCTAssertTrue(TypingTextContext.startsSentence(after: "Gut. ", rules: rules))
        XCTAssertTrue(TypingTextContext.startsSentence(after: "Am 3. ", rules: TypingLanguage.english.textRules))
        // An ellipsis after a number pauses the sentence in either language.
        XCTAssertFalse(TypingTextContext.startsSentence(after: "Bis 3... ", rules: rules))
    }

    func testWordEndingCharactersAreTheOnesApplesGermanKeyboardCorrectsBefore() throws {
        // Typed right after a misspelled word, the apostrophe key and a straight or curly
        // apostrophe from its popup left the word as typed; the quotation marks corrected it.
        let wordEnding = try CharacterList.wordEnding(for: .german)
        for character in [SmartQuotes.apostrophe, "'", "`"] {
            XCTAssertFalse(wordEnding.contains(character), character)
        }
        for mark in ["„", "“", "”", "«", "»", "\"", "‘", "‚", "‹", "›"] {
            XCTAssertTrue(wordEnding.contains(mark), mark)
        }
    }

    func testOnlyClosingPunctuationTakesAPickedWordsSpace() throws {
        // After a picked word, Apple's German keyboard kept the space before the apostrophe key's
        // mark and the straight and curly apostrophes, unlike English's.
        let list = try CharacterList.takingPickedWordSpace(for: .german)
        for character in [SmartQuotes.apostrophe, "'"] {
            XCTAssertFalse(list.contains(character), character)
        }
        for character in ["?", "!", ":", ".", ","] {
            XCTAssertTrue(list.contains(character), character)
        }
    }

    func testAPickedWordIsSpacedAwayFromGermansClosingMarks() throws {
        let list = try CharacterList.spacedFromPickedWord(for: .german)
        for mark in ["“", "”", "\"", "‘"] {
            XCTAssertTrue(list.contains(mark), mark)
        }
        XCTAssertFalse(list.contains("„"))
    }

    func testTheBarOffersNoNextWordsAfterTheMarksApplesGermanBarLeftEmpty() throws {
        // Held from the German keyboard's quote and apostrophe keys at the start of the text, Apple's
        // bar stayed empty after „ « » ‚ ‹ › and offered sentence openers after “ ” ".
        let list = try CharacterList.withoutNextWords(for: .german)
        for mark in ["„", "«", "»", "‚", "‹", "›"] {
            XCTAssertTrue(list.contains(mark), mark)
        }
        for mark in ["“", "”", "\"", "'", "’"] {
            XCTAssertFalse(list.contains(mark), mark)
        }
    }

    func testLetterKeysOfferApplesAccentsWithoutTheLettersThatHaveKeys() throws {
        let list = try HeldKeyCharacters.bundled(for: .german)
        XCTAssertEqual(list.offer(forKey: "a")?.characters, ["a", "à", "á", "â", "æ", "ã", "å", "ā"])
        XCTAssertEqual(list.offer(forKey: "o")?.characters, ["o", "ô", "ò", "ó", "õ", "œ", "ø", "ō"])
        XCTAssertEqual(list.offer(forKey: "u")?.characters, ["u", "û", "ù", "ú", "ū"])
        XCTAssertEqual(list.offer(forKey: "s")?.characters, ["s", "ß", "ś", "š"])
        XCTAssertEqual(list.offer(forKey: "S")?.characters, ["S", "ẞ", "Ś", "Š"])
        for key in ["z", "ä", "ö", "ü", "d", "l"] {
            XCTAssertNil(list.offer(forKey: key), key)
        }
        for (key, offer) in list.offersByKey where key.count == 1 && key.first!.isLetter {
            XCTAssertEqual(offer.characters.first, key)
            XCTAssertFalse(offer.characters.contains { "äöüÄÖÜ".contains($0) }, key)
        }
    }

    func testPunctuationPopupsLayOutAsApplesGermanKeyboardDrawsThem() throws {
        let list = try HeldKeyCharacters.bundled(for: .german)
        // The number page of a 440-point-wide iPhone, the keys where Apple's keyboard draws them.
        let bounds = CGRect(x: 0, y: 0, width: 440, height: 245)
        func drawn(_ key: String, keyFrame: CGRect) throws -> [String] {
            let offer = try XCTUnwrap(list.offer(forKey: key))
            let metrics = HeldKeyPopupLayout.Metrics(
                cellWidth: keyFrame.width - 2.1, // the key less its gap, plus the gap, less the reduction
                cellHeight: 47,
                padding: 10.2,
                gapAboveKey: 4.4,
                closingDistance: 87.8
            )
            let layout = HeldKeyPopupLayout(offer: offer, keyFrame: keyFrame, bounds: bounds, metrics: metrics)
            XCTAssertEqual(layout.firstCell.character, offer.characters[0])
            return layout.rows.flatMap { $0.map(\.character) }
        }
        XCTAssertEqual(
            try drawn(SmartQuotes.apostrophe, keyFrame: CGRect(x: 312, y: 119, width: 60.67, height: 56)),
            ["`", "‘", "›", "‹", "‚", "'", "’"]
        )
        XCTAssertEqual(
            try drawn("\"", keyFrame: CGRect(x: 394.33, y: 63, width: 43.33, height: 56)),
            ["»", "«", "”", "“", "„", "\""]
        )
    }

    func testALetterWithAKeyOfItsOwnIsAimedAtThatKey() throws {
        let keys = KeyCenterMap(geometry: TypingLanguage.german.letterLayout.defaultGeometry)
        let scorer = TouchAlignmentScorer(keys: keys, parameters: NoisyChannelCorrector.standardParameters.touch)
        let word = "über"
        let touches = try word.map { try XCTUnwrap(keys.center(of: $0)) }
        XCTAssertEqual(scorer.cost(of: touches, typing: word), 0, accuracy: 1e-9)
        // A letter with no key of its own is aimed at its plain letter's key.
        let english = KeyCenterMap(geometry: TypingLanguage.english.letterLayout.defaultGeometry)
        let englishScorer = TouchAlignmentScorer(keys: english, parameters: NoisyChannelCorrector.standardParameters.touch)
        let plainTouches = try "cafe".map { try XCTUnwrap(english.center(of: $0)) }
        XCTAssertEqual(englishScorer.cost(of: plainTouches, typing: "café"), 0, accuracy: 1e-9)
    }

    func testGermanLoadsItsDictionaryModelsAndWordLists() throws {
        XCTAssertNoThrow(try PredictiveEngine(language: .german))
    }

    func testGermanBundlesNoSwipeModelSoSwipingIsNotOffered() {
        XCTAssertFalse(TypingLanguage.german.offersSwipeTyping)
        XCTAssertTrue(TypingLanguage.english.offersSwipeTyping)
    }
}
