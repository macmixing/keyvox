import Foundation

extension DateFormatter {
    var keyVoxMonthSymbols: [String] {
        resolvedMonthSymbols(monthSymbols)
    }

    var keyVoxStandaloneMonthSymbols: [String] {
        resolvedMonthSymbols(standaloneMonthSymbols)
    }

    var keyVoxShortMonthSymbols: [String] {
        resolvedMonthSymbols(shortMonthSymbols)
    }

    var keyVoxShortStandaloneMonthSymbols: [String] {
        resolvedMonthSymbols(shortStandaloneMonthSymbols)
    }
}

private func resolvedMonthSymbols(_ symbols: [String]) -> [String] {
    symbols
}

private func resolvedMonthSymbols(_ symbols: [String]?) -> [String] {
    symbols ?? []
}
