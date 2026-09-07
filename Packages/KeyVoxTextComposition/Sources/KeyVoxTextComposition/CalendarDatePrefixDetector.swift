import Foundation

/// Date recognition needed by capitalization, rather than a general date parser.
package enum CalendarDatePrefixDetector {
    #if canImport(Darwin)
    private static let detector = try? NSDataDetector(
        types: NSTextCheckingResult.CheckingType.date.rawValue
    )
    #endif

    package static func startsWithDate(_ text: String, at index: String.Index, locale: Locale) -> Bool {
        #if canImport(Darwin)
        let range = NSRange(text.startIndex..<text.endIndex, in: text)
        let offset = NSRange(index..<index, in: text).location
        return detector?.firstMatch(in: text, range: range)?.range.location == offset
        #else
        return startsWithFullWeekday(text, at: index, locale: locale)
        #endif
    }

    package static func startsWithFullWeekday(_ text: String, at index: String.Index, locale: Locale) -> Bool {
        let formatter = DateFormatter()
        formatter.locale = locale
        var calendar = Calendar(identifier: .gregorian)
        calendar.locale = locale
        formatter.calendar = calendar

        let word = String(text[index...].prefix(while: \.isLetter))
        // Full weekday names identify calendar terms without interpreting prose.
        return formatter.weekdaySymbols.contains(word)
            || formatter.standaloneWeekdaySymbols.contains(word)
    }
}
