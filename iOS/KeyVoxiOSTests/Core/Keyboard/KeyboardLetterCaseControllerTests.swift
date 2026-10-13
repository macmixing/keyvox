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
        controller.synchronize(textBeforeCursor: textBeforeCursor, autocapitalization: .sentences)
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
}
