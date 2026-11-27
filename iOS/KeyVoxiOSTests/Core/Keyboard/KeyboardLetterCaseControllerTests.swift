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

    @Test func aSentenceOpeningMarkWhereASentenceStartsKeepsTheShift() {
        let marks = TypingLanguage.spanish.sentenceOpeningMarks.map(String.init)
        #expect(marks.isEmpty == false)
        for mark in marks {
            for before in ["", "A. ", "A?\n"] {
                #expect(shifts(after: before + mark, in: .spanish), "after \(before + mark)")
            }
            for before in ["a, ", "a "] {
                #expect(shifts(after: before + mark, in: .spanish) == false, "after \(before + mark)")
            }
            #expect(shifts(after: mark, in: .english) == false, "English after \(mark)")
        }
    }

    private func shifts(after textBeforeCursor: String, in language: TypingLanguage) -> Bool {
        KeyboardLetterCaseController.shouldAutoCapitalize(
            textBeforeCursor: textBeforeCursor,
            autocapitalization: .sentences,
            language: language
        )
    }
}

private extension TypingLanguage {
    static let english = try! TypingLanguage.bundled(identifier: "en")
    static let spanish = try! TypingLanguage.bundled(identifier: "es")
}
