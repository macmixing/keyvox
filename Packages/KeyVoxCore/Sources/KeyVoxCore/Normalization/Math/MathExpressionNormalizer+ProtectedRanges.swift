import Foundation

extension MathExpressionNormalizer {
    func replaceMatches(
        in text: String,
        using regex: NSRegularExpression?,
        transform: (_ match: NSTextCheckingResult, _ nsText: NSString) -> String?
    ) -> String {
        guard let regex else { return text }
        let nsText = text as NSString
        let range = NSRange(location: 0, length: nsText.length)
        let matches = regex.matches(in: text, options: [], range: range)
        guard !matches.isEmpty else { return text }

        let protectedRanges = protectedRanges(in: text)
        let mutable = NSMutableString(string: text)
        for match in matches.reversed() {
            if intersectsProtectedRange(match.range, protectedRanges: protectedRanges) {
                continue
            }
            guard let replacement = transform(match, nsText) else { continue }
            mutable.replaceCharacters(in: match.range, with: replacement)
        }

        return mutable as String
    }

    private func protectedRanges(in text: String) -> [NSRange] {
        var protected: [NSRange] = []
        protected.append(contentsOf: ranges(matching: Self.protectedEmailRegex, in: text))
        protected.append(contentsOf: ranges(matching: Self.protectedURLRegex, in: text))
        protected.append(contentsOf: ranges(matching: Self.protectedDomainRegex, in: text))
        protected.append(contentsOf: ranges(matching: Self.protectedTimeRegex, in: text))
        protected.append(contentsOf: ranges(matching: Self.protectedMalformedTimeWithMeridiemRegex, in: text))
        protected.append(contentsOf: ranges(matching: Self.protectedMalformedTimeWithDaypartRegex, in: text))
        protected.append(contentsOf: ranges(matching: Self.protectedDateRegex, in: text))
        protected.append(contentsOf: ranges(matching: Self.protectedVersionRegex, in: text))
        protected.append(contentsOf: ranges(matching: Self.protectedPhoneRegex, in: text))
        protected.append(contentsOf: compactHyphenatedNumericRanges(in: text))
        return protected
    }

    private func compactHyphenatedNumericRanges(in text: String) -> [NSRange] {
        guard let regex = Self.protectedCompactHyphenatedNumericRegex else { return [] }
        let nsText = text as NSString
        let fullRange = NSRange(location: 0, length: nsText.length)

        return regex.matches(in: text, options: [], range: fullRange).map(\.range)
    }

    private func ranges(matching regex: NSRegularExpression?, in text: String) -> [NSRange] {
        guard let regex else { return [] }
        let nsText = text as NSString
        let fullRange = NSRange(location: 0, length: nsText.length)
        return regex.matches(in: text, options: [], range: fullRange).map(\.range)
    }

    private func intersectsProtectedRange(_ range: NSRange, protectedRanges: [NSRange]) -> Bool {
        for protected in protectedRanges where NSIntersectionRange(range, protected).length > 0 {
            return true
        }
        return false
    }
}
