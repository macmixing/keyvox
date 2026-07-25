import Foundation

enum KeyboardLetterCase: Equatable {
    case lowercase
    case shifted
    case capsLocked

    var usesUppercaseLetters: Bool {
        self != .lowercase
    }
}

final class KeyboardLetterCaseController {
    private enum Timing {
        static let capsLockTapInterval: TimeInterval = 0.35
    }

    private(set) var letterCase: KeyboardLetterCase = .shifted
    private var lastShiftTapTimestamp: TimeInterval?

    func handleShift(at timestamp: TimeInterval = ProcessInfo.processInfo.systemUptime) {
        if let lastShiftTapTimestamp,
           timestamp - lastShiftTapTimestamp <= Timing.capsLockTapInterval {
            letterCase = .capsLocked
            self.lastShiftTapTimestamp = nil
            return
        }

        switch letterCase {
        case .lowercase:
            letterCase = .shifted
        case .shifted:
            letterCase = .lowercase
        case .capsLocked:
            letterCase = .lowercase
            lastShiftTapTimestamp = nil
            return
        }
        lastShiftTapTimestamp = timestamp
    }

    func consumeInsertedCharacter() {
        guard letterCase == .shifted else { return }
        letterCase = .lowercase
        lastShiftTapTimestamp = nil
    }

    func synchronize(documentContextBeforeInput: String?) {
        guard letterCase != .capsLocked else { return }
        let context = documentContextBeforeInput ?? ""
        let trimmed = context.trimmingCharacters(in: .whitespaces)
        let endsSentence = trimmed.last.map { character in
            character.isNewline || ".!?".contains(character)
        } ?? true
        if endsSentence {
            letterCase = .shifted
        } else {
            letterCase = .lowercase
        }
        lastShiftTapTimestamp = nil
    }
}
