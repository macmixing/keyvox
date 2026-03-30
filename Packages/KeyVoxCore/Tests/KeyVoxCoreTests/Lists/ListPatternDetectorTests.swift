import Foundation
import XCTest
@testable import KeyVoxCore

final class ListPatternDetectorTests: XCTestCase {
    func testDetectsNumberedListWithLeadIn() {
        let detector = ListPatternDetector()
        let text = "We need three things one get dog food two charge phone three call mom"

        let detected = detector.detectList(in: text)
        XCTAssertTrue(detected != nil)
        XCTAssertTrue(detected?.leadingText == "We need three things")
        XCTAssertTrue(detected?.items.count == 3)
        XCTAssertTrue(detected?.items.map(\.spokenIndex) == [1, 2, 3])
    }

    func testIgnoresSingleMarkerInput() {
        let detector = ListPatternDetector()
        let detected = detector.detectList(in: "one buy groceries")
        XCTAssertTrue(detected == nil)
    }

    func testIgnoresNumericProseThatIsNotMonotonicList() {
        let detector = ListPatternDetector()
        let detected = detector.detectList(in: "Version 1.2.3 shipped on 2026-02-14")
        XCTAssertTrue(detected == nil)
    }

    func testSplitsTrailingCommentaryFromLastListItem() {
        let detector = ListPatternDetector()
        let text = "For today one take the dog out two clean the kitchen three cook dinner tonight and now I can relax"

        let detected = detector.detectList(in: text)
        XCTAssertTrue(detected != nil)
        XCTAssertTrue(detected?.items.count == 3)
        XCTAssertTrue(detected?.trailingText == "and now I can relax")
    }

    func testSplitsCommaAndContinuationFromLastListItem() {
        let detector = ListPatternDetector()
        let text = "Okay so one when I make a list two it formats it properly three when I end the list, and everything's done"

        let detected = detector.detectList(in: text)
        XCTAssertTrue(detected != nil)
        XCTAssertTrue(detected?.items.count == 3)
        XCTAssertTrue(detected?.items.last?.content == "When I end the list")
        XCTAssertTrue(detected?.trailingText == "and everything's done")
    }

    func testSplitsShortNominalLastItemFromSentenceStyleCommentary() {
        let detector = ListPatternDetector()
        let text = "It's either going to be: one a dresser two a chair, and honestly I don't think you're going to pick wrong"

        let detected = detector.detectList(in: text)

        XCTAssertNotNil(detected)
        XCTAssertEqual(detected?.items.map(\.spokenIndex), [1, 2])
        XCTAssertEqual(detected?.items.map(\.content), ["A dresser", "A chair"])
        XCTAssertEqual(detected?.trailingText, "and honestly I don't think you're going to pick wrong")
    }

    func testPreservesCausalTransitionWhenSplittingLastItem() {
        let detector = ListPatternDetector()
        let text = "Today one get dog food two charge phone three call mom because we leave early"

        let detected = detector.detectList(in: text)
        XCTAssertTrue(detected != nil)
        XCTAssertTrue(detected?.items.count == 3)
        XCTAssertTrue(detected?.items.last?.content == "Call mom")
        XCTAssertTrue(detected?.trailingText == "because we leave early")
    }

    func testPreservesAndBecauseTransitionWhenSplittingLastItem() {
        let detector = ListPatternDetector()
        let text = "Today one get dog food two charge phone three call mom and because we leave early"

        let detected = detector.detectList(in: text)
        XCTAssertTrue(detected != nil)
        XCTAssertTrue(detected?.items.count == 3)
        XCTAssertTrue(detected?.items.last?.content == "Call mom")
        XCTAssertTrue(detected?.trailingText == "and because we leave early")
    }

    func testDetectsRestartedOneMarkersAcrossParagraphBreaks() {
        let detector = ListPatternDetector()
        let text = """
        For this trip:

        one pack charger

        one pack toothbrush

        one pack socks
        """

        let detected = detector.detectList(in: text)
        XCTAssertTrue(detected != nil)
        XCTAssertTrue(detected?.items.map(\.spokenIndex) == [1, 2, 3])
        XCTAssertTrue(detected?.items.map(\.content) == ["Pack charger", "Pack toothbrush", "Pack socks"])
    }

    func testDoesNotDetectRestartedOneMarkersWithoutParagraphBreaks() {
        let detector = ListPatternDetector()
        let text = "one pack charger one pack toothbrush one pack socks"

        let detected = detector.detectList(in: text)
        XCTAssertTrue(detected == nil)
    }

    func testPreservesParagraphBreaksInTrailingCommentary() {
        let detector = ListPatternDetector()
        let text = """
        Today one get dog food two charge phone three call mom and now this is important.

        This is still part of trailing commentary.
        """

        let detected = detector.detectList(in: text)
        XCTAssertTrue(detected != nil)
        XCTAssertEqual(
            detected?.trailingText,
            "and now this is important.\n\nThis is still part of trailing commentary."
        )
    }

    func testPrefersExplicitListMarkersOverIncidentalProseNumbers() {
        let detector = ListPatternDetector()
        let text = "This one is kind of interesting. It starts out probably about two months ago. One, Cueboard, Two, KeyVox"

        let detected = detector.detectList(in: text)
        XCTAssertTrue(detected != nil)
        XCTAssertTrue(detected?.items.count == 2)
        XCTAssertTrue(detected?.items.map(\.spokenIndex) == [1, 2])
        XCTAssertTrue(detected?.items.map(\.content) == ["Cueboard", "KeyVox"])
    }

    func testSplitsLongLastItemForUserExampleOne() {
        let detector = ListPatternDetector()
        let text = """
        1. I need to make a list of things
        2. I need to go to the grocery store
        3. there's no way out of here. After all that, I'm going to have to do something with my brain

        Because now it's raining outside and I can't take my dog to go to the bathroom.
        """

        let detected = detector.detectList(in: text)
        XCTAssertTrue(detected != nil)
        XCTAssertTrue(detected?.items.map(\.spokenIndex) == [1, 2, 3])
        XCTAssertTrue(detected?.items.last?.content == "There's no way out of here.")
        XCTAssertTrue(
            detected?.trailingText
                == "After all that, I'm going to have to do something with my brain\n\nBecause now it's raining outside and I can't take my dog to go to the bathroom."
        )
    }

    func testSplitsLongSecondItemForUserExampleTwo() {
        let detector = ListPatternDetector()
        let text = """
        1. go to the store
        2. get some groceries, and by the end of the day we'll probably have nothing else left to fix, but these couple of things

        Because that's just what we do.
        """

        let detected = detector.detectList(in: text)
        XCTAssertTrue(detected != nil)
        XCTAssertTrue(detected?.items.map(\.spokenIndex) == [1, 2])
        XCTAssertTrue(detected?.items.last?.content == "Get some groceries")
        XCTAssertTrue(
            detected?.trailingText
                == "and by the end of the day we'll probably have nothing else left to fix, but these couple of things\n\nBecause that's just what we do."
        )
    }

    func testSplitsLongLastItemWhenListStartsAtTwo() {
        let detector = ListPatternDetector()
        let text = """
        2. I need to go to the grocery store
        3. there's no way out of here. After all that, I'm going to have to do something with my brain

        Because now it's raining outside and I can't take my dog to go to the bathroom.
        """

        let detected = detector.detectList(in: text)
        XCTAssertTrue(detected != nil)
        XCTAssertTrue(detected?.items.map(\.spokenIndex) == [2, 3])
        XCTAssertTrue(detected?.items.last?.content == "There's no way out of here.")
        XCTAssertTrue(
            detected?.trailingText
                == "After all that, I'm going to have to do something with my brain\n\nBecause now it's raining outside and I can't take my dog to go to the bathroom."
        )
    }

    func testSplitsShortNominalLastItemFromCommaThenContinuation() {
        let detector = ListPatternDetector()
        let text = """
        I need to go to the store today to pick up some things:

        1. Apples
        2. Oranges
        3. Bananas, and then I need to go to Target to buy some clothes
        """

        let detected = detector.detectList(in: text)
        XCTAssertNotNil(detected)
        XCTAssertEqual(detected?.items.map(\.spokenIndex), [1, 2, 3])
        XCTAssertEqual(detected?.items.map(\.content), ["Apples", "Oranges", "Bananas"])
        XCTAssertEqual(detected?.trailingText, "and then I need to go to Target to buy some clothes")
    }

    func testSplitsSpokenMarkerLastItemFromCommaThenContinuation() {
        let detector = ListPatternDetector()
        let text = "I need to go to the store today to pick up some things. One, apples, two, oranges, three, bananas, and then I need to go to Target to buy some clothes."

        let detected = detector.detectList(in: text)
        XCTAssertNotNil(detected)
        XCTAssertEqual(detected?.items.map(\.spokenIndex), [1, 2, 3])
        XCTAssertEqual(detected?.items.map(\.content), ["Apples", "Oranges", "Bananas"])
        XCTAssertEqual(detected?.trailingText, "and then I need to go to Target to buy some clothes.")
    }

    func testDoesNotLetBecauseSplitHideEarlierSentenceBoundary() {
        let detector = ListPatternDetector()
        let text = """
        1. go to the store
        2. get some groceries. There's really nothing else to do, but just talk a little bit more and hope this splits things out right

        Because I'm just trying to make it work.
        """

        let detected = detector.detectList(in: text)
        XCTAssertTrue(detected != nil)
        XCTAssertTrue(detected?.items.map(\.spokenIndex) == [1, 2])
        XCTAssertTrue(detected?.items.last?.content == "Get some groceries.")
        XCTAssertTrue(
            detected?.trailingText
                == "There's really nothing else to do, but just talk a little bit more and hope this splits things out right\n\nBecause I'm just trying to make it work."
        )
    }

    func testStripsTerminalPunctuationFromShortListItems() {
        let detector = ListPatternDetector()
        let text = "one buy groceries, two walk dog."

        let detected = detector.detectList(in: text)
        XCTAssertTrue(detected != nil)
        XCTAssertTrue(detected?.items.map(\.spokenIndex) == [1, 2])
        XCTAssertTrue(detected?.items.map(\.content) == ["Buy groceries", "Walk dog"])
    }

    func testPreservesTerminalPunctuationForLongerListItems() {
        let detector = ListPatternDetector()
        let text = """
        1. Write the full summary.
        2. Walk dog.
        3. Double-check the release notes!
        """

        let detected = detector.detectList(in: text)
        XCTAssertNotNil(detected)
        XCTAssertEqual(detected?.items.map(\.spokenIndex), [1, 2, 3])
        XCTAssertEqual(detected?.items.map(\.content), [
            "Write the full summary.",
            "Walk dog",
            "Double-check the release notes!",
        ])
    }

    func testStripsStructuralCommaFromLongerSpokenListItem() {
        let detector = ListPatternDetector()
        let text = "Need two things one write the full summary, two walk dog"

        let detected = detector.detectList(in: text)
        XCTAssertNotNil(detected)
        XCTAssertEqual(detected?.items.map(\.spokenIndex), [1, 2])
        XCTAssertEqual(detected?.items.map(\.content), [
            "Write the full summary",
            "Walk dog",
        ])
    }

    func testKeepsFormattingWhenSpokenNumberSkipsAhead() {
        let detector = ListPatternDetector()
        let text = "Today one buy groceries two walk dog four call mom five charge phone"

        let detected = detector.detectList(in: text)
        XCTAssertTrue(detected != nil)
        XCTAssertTrue(detected?.items.map(\.spokenIndex) == [1, 2, 4, 5])
        XCTAssertTrue(detected?.items.map(\.content) == ["Buy groceries", "Walk dog", "Call mom", "Charge phone"])
    }

    func testDoesNotDetectTwoItemNonConsecutiveProseNumbers() {
        let detector = ListPatternDetector()
        let text = "I need one for my desk and three for the office"

        let detected = detector.detectList(in: text)
        XCTAssertNil(detected)
    }

    func testDoesNotDetectOrdinalFractionPhraseInProse() {
        let detector = ListPatternDetector()
        let text = "Now the key is about one third too wide and it bleeds into the nine key next to it"

        let detected = detector.detectList(in: text)
        XCTAssertNil(detected)
    }

    func testDoesNotDetectListWhenSecondMarkerArrivesAfterLongProseSpan() {
        let detector = ListPatternDetector()
        let text = """
        1. Was that LMS couldn't do it. This is a long explanation about model scores and benchmarks and how numbers online can be misleading if you don't understand the context. We keep talking through a lot of details, examples, comparisons, and side notes because the point is not to make a numbered list at all. It's just a long paragraph where a spoken number happened at the start and then another number appears much later in regular prose after a lot of sentences and commentary and transitions.
        2. on your computer, right
        """

        let detected = detector.detectList(in: text)
        XCTAssertNil(detected)
    }

    func testDoesNotDetectTwoItemSpokenNumbersInsideLongProseSentence() {
        let detector = ListPatternDetector()
        let text = "I was testing dictation with a long form YouTube video where the user said the number one initially and then later on after long prose they said the number two and they just kept going"

        let detected = detector.detectList(in: text)
        XCTAssertNil(detected)
    }

    func testDoesNotDetectTwoItemSpokenNumbersAcrossSentenceBoundaryInProse() {
        let detector = ListPatternDetector()
        let text = "If I double click into the mirror, it only shows me the one single half. It's not two separate shapes"

        let detected = detector.detectList(in: text)
        XCTAssertNil(detected)
    }

    func testDoesNotDetectTwoItemSpokenNumbersInRequestProse() {
        let detector = ListPatternDetector()
        let text = "Why is it that I ask you for one pie you always bring two apples"

        let detected = detector.detectList(in: text)
        XCTAssertNil(detected)
    }

    func testDoesNotDetectListFromUncertainNumericRangeInProse() {
        let detector = ListPatternDetector()
        let text = """
        One thing real quickly, and that is just to adjust the size of the individual keys. Maybe like, I don't know two or three points taller. Something like that.
        """

        let detected = detector.detectList(in: text)
        XCTAssertNil(detected)
    }

    func testDetectsExplicitTwoItemListAfterColonEvenWhenItemOneIsLong() {
        let detector = ListPatternDetector()
        let text = """
        I was testing dictation with a long form YouTube video where the user said the number:

        1. Initially and then later on after long prose they said the number
        2. They just kept going
        """

        let detected = detector.detectList(in: text)
        XCTAssertNotNil(detected)
        XCTAssertEqual(detected?.items.map(\.spokenIndex), [1, 2])
    }

    func testDetectsListWhenCadenceRecoversAtThirdMarkerAfterLongFirstItem() {
        let detector = ListPatternDetector()
        let text = """
        1. This first item is intentionally long. It has multiple sentences because someone is explaining context before they continue the list. They keep talking for a while to set things up and it goes on longer than a normal list item would.
        2. Cueboard
        3. KeyVox
        """

        let detected = detector.detectList(in: text)
        XCTAssertNotNil(detected)
        XCTAssertEqual(detected?.items.map(\.spokenIndex), [1, 2, 3])
        XCTAssertEqual(detected?.items.map(\.content), [
            "This first item is intentionally long. It has multiple sentences because someone is explaining context before they continue the list. They keep talking for a while to set things up and it goes on longer than a normal list item would.",
            "Cueboard",
            "KeyVox",
        ])
    }

    func testDetectsExplicitTwoItemNonConsecutiveListMarkers() {
        let detector = ListPatternDetector()
        let text = "1. buy groceries 3. call mom"

        let detected = detector.detectList(in: text)
        XCTAssertNotNil(detected)
        XCTAssertEqual(detected?.items.map(\.spokenIndex), [1, 3])
        XCTAssertEqual(detected?.items.map(\.content), ["Buy groceries", "Call mom"])
    }

    func testDetectsSpokenMarkersBeyondTwelveWithoutHardCap() {
        let detector = ListPatternDetector()
        let text = "For release: twelve fix parser thirteen ship build fourteen tag release"

        let detected = detector.detectList(in: text)
        XCTAssertNotNil(detected)
        XCTAssertEqual(detected?.items.map(\.spokenIndex), [12, 13, 14])
        XCTAssertEqual(detected?.items.map(\.content), ["Fix parser", "Ship build", "Tag release"])
    }

    func testDoesNotTriggerListFromOneForOnePhrase() {
        let detector = ListPatternDetector()
        let text = """
        The migration should match one for one across environments. But should we run the validation right now and check if the output is identical? There should only be two extra rows in the summary report.
        """

        let detected = detector.detectList(in: text)
        XCTAssertNil(detected)
    }

    func testDoesNotDetectListFromQuantifiedChoiceSentence() {
        let detector = ListPatternDetector()
        let text = "It's only one of those two choices and you're not allowed to have it."

        let detected = detector.detectList(in: text)

        XCTAssertNil(detected)
    }

    func testDetectsSecondMarkerWhenAttachedAfterEmailDomain() {
        let detector = ListPatternDetector()
        let text = "I have a couple of email addresses. Let me give them to you: 1. Dom at example.com2. Kathy at example.com"

        let detected = detector.detectList(in: text)
        XCTAssertNotNil(detected)
        XCTAssertEqual(detected?.items.map(\.spokenIndex), [1, 2])
    }

    func testDoesNotDetectListFromQuestionWithStepNumber() {
        let detector = ListPatternDetector()
        let text = "Where did you say 2. pause in step 3. where you talked about it?"

        let detected = detector.detectList(in: text)
        XCTAssertNil(detected)
    }

    func testDoesNotTreatToAsSecondMarkerInRegularSentence() {
        let detector = ListPatternDetector()
        let text = "1. send email to dom@example.com"

        let detected = detector.detectList(in: text)
        XCTAssertNil(detected)
    }

    func testTreatsToAsSecondMarkerForExplicitEmailListItems() {
        let detector = ListPatternDetector()
        let text = "1. dom@example.com to kathy@example.com"

        let detected = detector.detectList(in: text)
        XCTAssertNotNil(detected)
        XCTAssertEqual(detected?.items.map(\.spokenIndex), [1, 2])
        XCTAssertEqual(detected?.items.map(\.content), ["Dom@example.com", "Kathy@example.com"])
    }

    func testDetectsSpanishSpokenMarkers() {
        let detector = ListPatternDetector()
        let text = "Para hoy: uno comprar leche dos caminar con el perro tres llamar a mamá"
        
        let detected = detector.detectList(in: text, languageCode: "es")
        XCTAssertNotNil(detected)
        XCTAssertTrue(detected?.items.map(\.spokenIndex) == [1, 2, 3])
        XCTAssertTrue(detected?.items.map(\.content) == ["Comprar leche", "Caminar con el perro", "Llamar a mamá"])
    }

    func testDetectsFrenchSpokenMarkers() {
        let detector = ListPatternDetector()
        let text = "Liste de courses: un du pain deux du lait trois des oeufs"
        
        let detected = detector.detectList(in: text, languageCode: "fr")
        XCTAssertNotNil(detected)
        XCTAssertTrue(detected?.items.map(\.spokenIndex) == [1, 2, 3])
        XCTAssertTrue(detected?.items.map(\.content) == ["Du pain", "Du lait", "Des oeufs"])
    }

    func testSpokenMarkersNotDetectedForMismatchedLanguage() {
        let detector = ListPatternDetector()
        let text = "un buy groceries deux walk dog"
        
        // Should not detect if language is set to English but markers are French
        let detected = detector.detectList(in: text, languageCode: "en")
        XCTAssertNil(detected)
    }

    func testNumericMarkersStillWorkWithUnknownLanguage() {
        let detector = ListPatternDetector()
        let text = "1. buy groceries 2. walk dog"
        
        let detected = detector.detectList(in: text, languageCode: "unknown")
        XCTAssertNotNil(detected)
        XCTAssertEqual(detected?.items.map(\.spokenIndex), [1, 2])
    }
}
