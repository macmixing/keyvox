import Foundation

/// Spans whose numbers must retain their spelling, plus the kinds actually
/// examined. An unavailable detector is different from a successful empty result.
struct NumericTextProtection {
    enum Category: CaseIterable { case date, address }
    let ranges: [NSRange]
    let availableCategories: Set<Category>

    var isComplete: Bool { availableCategories == Set(Category.allCases) }
}

protocol NumericTextProtectionAnalyzing {
    func analyze(_ text: String) -> NumericTextProtection
}
