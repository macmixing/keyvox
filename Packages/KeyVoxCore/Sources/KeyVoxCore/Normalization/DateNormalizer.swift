import Foundation

public struct DateNormalizer {
    private let calendar: Calendar
    private let monthIndexByToken: [String: Int]
    private let monthPattern: String
    private let outputFormatter: DateFormatter
    private let spellOutFormatter: NumberFormatter

    public init(locale: Locale = Locale(identifier: "en_US_POSIX")) {
        var calendar = Calendar(identifier: .gregorian)
        calendar.locale = locale
        self.calendar = calendar

        let monthFormatter = DateFormatter()
        monthFormatter.locale = locale
        monthFormatter.calendar = calendar

        var monthIndexByToken: [String: Int] = [:]
        let monthTokenGroups = [
            monthFormatter.monthSymbols ?? [],
            monthFormatter.standaloneMonthSymbols ?? [],
            monthFormatter.shortMonthSymbols ?? [],
            monthFormatter.shortStandaloneMonthSymbols ?? [],
        ]

        for symbols in monthTokenGroups {
            for (index, symbol) in symbols.enumerated() where !symbol.isEmpty {
                monthIndexByToken[symbol.lowercased()] = index + 1
            }
        }

        self.monthIndexByToken = monthIndexByToken
        self.monthPattern = monthIndexByToken.keys
            .sorted { $0.count > $1.count }
            .map(NSRegularExpression.escapedPattern(for:))
            .joined(separator: "|")

        let outputFormatter = DateFormatter()
        outputFormatter.locale = locale
        outputFormatter.calendar = calendar
        outputFormatter.dateFormat = "MMMM d, yyyy"
        self.outputFormatter = outputFormatter

        let spellOutFormatter = NumberFormatter()
        spellOutFormatter.locale = locale
        spellOutFormatter.numberStyle = .spellOut
        self.spellOutFormatter = spellOutFormatter
    }

    public func normalize(in text: String) -> String {
        guard !text.isEmpty, !monthPattern.isEmpty else { return text }

        let dayPattern = #"(?:\d{1,2}(?:st|nd|rd|th)?|[A-Za-z]+(?:[- ][A-Za-z]+)?)"#
        let yearPattern = #"(?:\d{1,4}(?:,\d{3})*|[A-Za-z]+(?:[- ][A-Za-z]+){0,2})"#
        let pattern = #"\b(\#(monthPattern))\s+(\#(dayPattern))(?:,)?\s+(\#(yearPattern))(?=$|[\s\.\,\!\?\;\:\)])"#

        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) else {
            return text
        }

        let nsText = text as NSString
        let mutable = NSMutableString(string: text)
        let fullRange = NSRange(location: 0, length: nsText.length)
        let matches = regex.matches(in: text, options: [], range: fullRange)

        for match in matches.reversed() {
            let monthToken = nsText.substring(with: match.range(at: 1))
            let dayToken = nsText.substring(with: match.range(at: 2))
            let yearToken = nsText.substring(with: match.range(at: 3))

            guard let month = monthNumber(for: monthToken),
                  let day = dayValue(for: dayToken),
                  let year = yearValue(for: yearToken),
                  let date = validatedDate(year: year, month: month, day: day) else {
                continue
            }

            mutable.replaceCharacters(in: match.range, with: outputFormatter.string(from: date))
        }

        return mutable as String
    }

    private func monthNumber(for token: String) -> Int? {
        monthIndexByToken[token.lowercased()]
    }

    private func dayValue(for token: String) -> Int? {
        if let numericDay = numericValue(for: token), (1...31).contains(numericDay) {
            return numericDay
        }

        guard let spokenDay = spokenNumberValue(for: token), (1...31).contains(spokenDay) else {
            return nil
        }

        return spokenDay
    }

    private func yearValue(for token: String) -> Int? {
        if let numericYear = numericValue(for: token), (1000...2999).contains(numericYear) {
            return numericYear
        }

        guard let spokenYear = spokenNumberValue(for: token), (1000...2999).contains(spokenYear) else {
            return nil
        }

        return spokenYear
    }

    private func numericValue(for token: String) -> Int? {
        let normalized = token
            .replacingOccurrences(of: #"(st|nd|rd|th)$"#, with: "", options: [.regularExpression, .caseInsensitive])
            .replacingOccurrences(of: ",", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return Int(normalized)
    }

    private func spokenNumberValue(for token: String) -> Int? {
        let normalized = token
            .lowercased()
            .replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalized.isEmpty else { return nil }

        for candidate in spokenNumberCandidates(for: normalized) {
            if let number = spellOutFormatter.number(from: candidate)?.intValue {
                return number
            }
        }

        return nil
    }

    private func spokenNumberCandidates(for normalized: String) -> [String] {
        var candidates = [normalized]
        let tokens = normalized.split(separator: " ").map(String.init)

        if tokens.count == 2 {
            candidates.append(tokens.joined(separator: "-"))
        } else if tokens.count > 2 {
            let head = tokens.dropLast(2).joined(separator: " ")
            let tail = tokens.suffix(2).joined(separator: "-")
            candidates.append([head, tail].filter { !$0.isEmpty }.joined(separator: " "))
        }

        return Array(NSOrderedSet(array: candidates)) as? [String] ?? candidates
    }

    private func validatedDate(year: Int, month: Int, day: Int) -> Date? {
        let components = DateComponents(calendar: calendar, year: year, month: month, day: day)
        guard let date = calendar.date(from: components) else { return nil }

        let resolved = calendar.dateComponents([.year, .month, .day], from: date)
        guard resolved.year == year, resolved.month == month, resolved.day == day else {
            return nil
        }

        return date
    }
}
