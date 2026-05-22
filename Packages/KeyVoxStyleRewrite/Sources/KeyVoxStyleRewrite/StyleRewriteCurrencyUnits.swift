import Foundation

enum StyleRewriteCurrencyUnits {
    struct Unit {
        let symbol: String
        let scale: Scale
    }

    enum Scale {
        case major
        case minor
    }

    private static let unitsByLemma: [String: Unit] = [
        "agora": Unit(symbol: "₪", scale: .minor),
        "baht": Unit(symbol: "฿", scale: .major),
        "buck": Unit(symbol: "$", scale: .major),
        "cent": Unit(symbol: "$", scale: .minor),
        "centavo": Unit(symbol: "$", scale: .minor),
        "centime": Unit(symbol: "Fr", scale: .minor),
        "crown": Unit(symbol: "kr", scale: .major),
        "dinar": Unit(symbol: "د.ك", scale: .major),
        "dirham": Unit(symbol: "د.إ", scale: .major),
        "dong": Unit(symbol: "₫", scale: .major),
        "dollar": Unit(symbol: "$", scale: .major),
        "euro": Unit(symbol: "€", scale: .major),
        "fil": Unit(symbol: "د.ك", scale: .minor),
        "fils": Unit(symbol: "د.ك", scale: .minor),
        "forint": Unit(symbol: "Ft", scale: .major),
        "franc": Unit(symbol: "Fr", scale: .major),
        "grosz": Unit(symbol: "zł", scale: .minor),
        "haler": Unit(symbol: "Kč", scale: .minor),
        "krona": Unit(symbol: "kr", scale: .major),
        "krone": Unit(symbol: "kr", scale: .major),
        "koruna": Unit(symbol: "Kč", scale: .major),
        "lira": Unit(symbol: "₺", scale: .major),
        "paise": Unit(symbol: "₹", scale: .minor),
        "pence": Unit(symbol: "£", scale: .minor),
        "penny": Unit(symbol: "£", scale: .minor),
        "peso": Unit(symbol: "$", scale: .major),
        "pound": Unit(symbol: "£", scale: .major),
        "rand": Unit(symbol: "R", scale: .major),
        "real": Unit(symbol: "R$", scale: .major),
        "rial": Unit(symbol: "﷼", scale: .major),
        "riyal": Unit(symbol: "﷼", scale: .major),
        "ruble": Unit(symbol: "₽", scale: .major),
        "rouble": Unit(symbol: "₽", scale: .major),
        "rupee": Unit(symbol: "₹", scale: .major),
        "sen": Unit(symbol: "¥", scale: .minor),
        "shekel": Unit(symbol: "₪", scale: .major),
        "won": Unit(symbol: "₩", scale: .major),
        "yen": Unit(symbol: "¥", scale: .major),
        "yuan": Unit(symbol: "¥", scale: .major),
        "zloty": Unit(symbol: "zł", scale: .major),
    ]

    static let symbolPattern: String = Array(Set(unitsByLemma.values.map(\.symbol)))
        .sorted { left, right in
            if left.count == right.count {
                return left < right
            }
            return left.count > right.count
        }
        .map { NSRegularExpression.escapedPattern(for: $0) }
        .joined(separator: "|")

    static func unit(for lemma: String?) -> Unit? {
        guard let lemma else { return nil }
        return unitsByLemma[lemma.lowercased()]
    }
}
