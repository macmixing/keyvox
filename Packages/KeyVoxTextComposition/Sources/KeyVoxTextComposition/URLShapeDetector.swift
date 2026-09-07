import Foundation

enum URLShapeDetector {
    #if canImport(Darwin)
    private static let detector = try? NSDataDetector(
        types: NSTextCheckingResult.CheckingType.link.rawValue
    )
    #endif

    static func startsWithURL(afterLeadingWhitespaceIn text: String) -> Bool {
        let candidate = String(text.drop(while: \.isWhitespace))
        #if canImport(Darwin)
        guard candidate.isEmpty == false, let detector else { return false }

        let range = NSRange(candidate.startIndex..<candidate.endIndex, in: candidate)
        guard let match = detector.firstMatch(in: candidate, range: range) else {
            return false
        }
        return match.resultType == .link && match.range.location == 0
        #else
        return PortableLinkPrefixDetector.startsWithLink(candidate)
        #endif
    }
}
