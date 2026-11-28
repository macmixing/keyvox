import KeyVoxPredictiveKeyboard
import Testing
import UIKit
@testable import KeyVox_iOS

struct KeyboardLetterCaseControllerTests {
    @Test func quickSecondShiftTapLocksCaps() {
        let controller = KeyboardLetterCaseController()

        controller.handleShift(at: 0, allowsCapsLock: true)
        controller.handleShift(at: 0.1, allowsCapsLock: true)

        #expect(controller.letterCase == .capsLocked)
    }

    @Test(arguments: ["", "Hello. "])
    func quickDoubleShiftTapLocksCapsWhenTheFieldShifted(textBeforeCursor: String) {
        let controller = KeyboardLetterCaseController()
        controller.synchronize(textBeforeCursor: textBeforeCursor, autocapitalization: .sentences, language: .english)
        #expect(controller.letterCase == .shifted)

        controller.handleShift(at: 0, allowsCapsLock: true)
        controller.handleShift(at: 0.1, allowsCapsLock: true)

        #expect(controller.letterCase == .capsLocked)
    }

    @Test func quickSecondShiftTapWithCapsLockOffTurnsShiftOff() {
        let controller = KeyboardLetterCaseController()

        controller.handleShift(at: 0, allowsCapsLock: false)
        controller.handleShift(at: 0.1, allowsCapsLock: false)

        #expect(controller.letterCase == .lowercase)
    }

    @Test func germanOrdinalNumbersPeriodKeepsTheSentenceGoing() {
        // Apple's German keyboard leaves shift off after "Am 3. ", and on after "Gut. ".
        #expect(KeyboardLetterCaseController.shouldAutoCapitalize(
            textBeforeCursor: "Am 3. ",
            autocapitalization: .sentences,
            language: .german
        ) == false)
        #expect(KeyboardLetterCaseController.shouldAutoCapitalize(
            textBeforeCursor: "Gut. ",
            autocapitalization: .sentences,
            language: .german
        ))
        #expect(KeyboardLetterCaseController.shouldAutoCapitalize(
            textBeforeCursor: "Am 3. ",
            autocapitalization: .sentences,
            language: .english
        ))
    }
}

private extension TypingLanguage {
    static let english = try! TypingLanguage.bundled(identifier: "en")
    static let german = try! TypingLanguage.bundled(identifier: "de")
}
