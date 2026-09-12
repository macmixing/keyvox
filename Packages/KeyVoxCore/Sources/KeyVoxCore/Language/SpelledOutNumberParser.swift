import Foundation
import CoreFoundation

/// Parses a complete number phrase without accepting and discarding unparsed text.
/// Callers own language selection and any surrounding phrase normalization.
final class SpelledOutNumberParser {
    private let formatter: CFNumberFormatter?
    private let lock = NSLock()

    init(locale: Locale) {
        guard let identifier = CFLocaleCreateCanonicalLocaleIdentifierFromString(nil, Self.cfString(locale.identifier)),
              let cfLocale = CFLocaleCreate(nil, identifier) else {
            formatter = nil
            return
        }
        formatter = CFNumberFormatterCreate(nil, cfLocale, .spellOutStyle)
    }

    func number(from text: String) -> NSNumber? {
        guard !text.isEmpty else { return nil }
        return lock.withLock {
            guard let formatter else { return nil }
            let input = Self.cfString(text)
            let length = CFStringGetLength(input)
            var consumed = CFRange(location: 0, length: length)
            guard let number = CFNumberFormatterCreateNumberFromString(nil, formatter, input, &consumed, 0),
                  consumed.location == 0, consumed.length == length else { return nil }

            if CFNumberIsFloatType(number) {
                var value: Double = 0
                guard CFNumberGetValue(number, .doubleType, &value) else { return nil }
                return NSNumber(value: value)
            }
            var value: Int64 = 0
            guard CFNumberGetValue(number, .sInt64Type, &value) else { return nil }
            return NSNumber(value: value)
        }
    }

    private static func cfString(_ value: String) -> CFString {
        let bytes = Array(value.utf8)
        return CFStringCreateWithBytes(nil, bytes, bytes.count, CFStringBuiltInEncodings.UTF8.rawValue, false)
    }
}
