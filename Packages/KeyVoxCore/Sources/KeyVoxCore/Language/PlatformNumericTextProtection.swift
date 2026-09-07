import Foundation

struct PlatformNumericTextProtection: NumericTextProtectionAnalyzing {
    #if canImport(Darwin)
    private static let dateDetector = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.date.rawValue)
    private static let addressDetector = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.address.rawValue)
    #endif

    func analyze(_ text: String) -> NumericTextProtection {
        #if canImport(Darwin)
        let detectors: [(NumericTextProtection.Category, NSDataDetector?)] = [
            (.date, Self.dateDetector), (.address, Self.addressDetector),
        ]
        let fullRange = NSRange(text.startIndex..<text.endIndex, in: text)
        var ranges: [NSRange] = []
        var available: Set<NumericTextProtection.Category> = []
        for (category, detector) in detectors {
            guard let detector else { continue }
            available.insert(category)
            ranges += detector.matches(in: text, options: [], range: fullRange).map(\.range)
        }
        return NumericTextProtection(ranges: ranges, availableCategories: available)
        #else
        // Temporary capability gap, explicitly propagated to conservative callers.
        return NumericTextProtection(ranges: [], availableCategories: [])
        #endif
    }
}
