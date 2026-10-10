import XCTest

/// Reads the labels in a keyboard's suggestion bar, the band between the keyboard's top edge
/// and its first row of keys, from left to right. It reads one listing of every element, the
/// keyboard's included, as the bar changes while it is read element by element.
struct SuggestionBarReader {
    private static let elementPattern = try! NSRegularExpression(
        pattern: #"\{\{(-?[\d.]+), (-?[\d.]+)\}, \{([\d.]+), ([\d.]+)\}\}.*?label: '(.*?)'(?=, |$)"#,
        options: .anchorsMatchLines
    )

    private let app: XCUIApplication
    let barTop: CGFloat
    let barBottom: CGFloat

    init(app: XCUIApplication, firstRowKey: XCUIElement) {
        self.app = app
        barBottom = firstRowKey.frame.minY
        barTop = barBottom - 80
    }

    func read() -> [String] {
        var labels: [(CGFloat, String)] = []
        let listing = app.debugDescription as NSString
        let matches = Self.elementPattern.matches(in: listing as String, range: NSRange(location: 0, length: listing.length))
        for match in matches {
            let number = { (index: Int) in CGFloat(Double(listing.substring(with: match.range(at: index))) ?? 0) }
            let frame = CGRect(x: number(1), y: number(2), width: number(3), height: number(4))
            let label = listing.substring(with: match.range(at: 5))
            if contains(frame), label.isEmpty == false {
                labels.append((frame.midX, label))
            }
        }
        var seen: Set<String> = []
        return labels.sorted { $0.0 < $1.0 }.map(\.1).filter { seen.insert($0).inserted }
    }

    /// The bar once the keyboard has filled it: an empty bar is read again for a few seconds
    /// before it counts as empty.
    func readSettled() -> [String] {
        var bar = read()
        for _ in 0..<10 where bar.isEmpty {
            Thread.sleep(forTimeInterval: 0.3)
            bar = read()
        }
        return bar
    }

    /// Whether an element with this frame is one of the bar's entries.
    func contains(_ frame: CGRect) -> Bool {
        frame.midY > barTop && frame.midY < barBottom && frame.width > 20 && frame.width < 300
    }
}
