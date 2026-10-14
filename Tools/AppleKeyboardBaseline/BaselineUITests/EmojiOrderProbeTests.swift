import XCTest

/// Records the order the system emoji keyboard shows its emoji in, by watching it: scrolls its
/// grid from the start to the end, places every emoji and section title it sees at its position
/// along the whole grid, and writes each section's title and emoji in order, as JSON, to
/// `EMOJI_ORDER_OUTPUT`.
final class EmojiOrderProbeTests: XCTestCase {
    private struct Seen {
        let x: CGFloat
        let y: CGFloat
        let label: String
    }

    private struct Section: Encodable {
        let title: String
        let emoji: [String]
    }

    func testRecordEmojiOrder() throws {
        let outputPath = try XCTUnwrap(ProcessInfo.processInfo.environment["EMOJI_ORDER_OUTPUT"], "EMOJI_ORDER_OUTPUT is not set")
        let app = XCUIApplication()
        app.launch()
        let input = app.textViews["input"]
        XCTAssertTrue(input.waitForExistence(timeout: 15))
        input.tap()
        XCTAssertTrue(KeyboardSwitcher.switchToSystemKeyboard(in: app))
        let emojiKey = app.keyboards.buttons["Emoji"]
        XCTAssertTrue(emojiKey.waitForExistence(timeout: 3), "no Emoji key")
        emojiKey.tap()
        Thread.sleep(forTimeInterval: 1.5)
        let first = app.descendants(matching: .any).matching(NSPredicate(format: "label == %@", "Frequently Used category")).firstMatch
        XCTAssertTrue(first.waitForExistence(timeout: 3), "no Frequently Used category")
        first.tap()
        Thread.sleep(forTimeInterval: 0.8)

        var emoji: [Seen] = []
        var titles: [Seen] = []
        var stepsWithoutNewEmoji = 0
        while stepsWithoutNewEmoji < 2 {
            let (cells, headers) = try Self.visible(in: app)
            let offset = try Self.offset(of: cells, against: emoji)
            var added = 0
            for cell in cells where emoji.contains(where: { abs($0.x - (cell.x + offset)) < 2 && abs($0.y - cell.y) < 2 }) == false {
                emoji.append(Seen(x: cell.x + offset, y: cell.y, label: cell.label))
                added += 1
            }
            for header in headers where titles.contains(where: { $0.label == header.label }) == false {
                titles.append(Seen(x: header.x + offset, y: header.y, label: header.label))
            }
            stepsWithoutNewEmoji = added == 0 ? stepsWithoutNewEmoji + 1 : 0
            print("EMOJI-ORDER step cells=\(cells.count) offset=\(offset) added=\(added) headers=\(headers.map(\.label)) first=\(cells.min { ($0.x, $0.y) < ($1.x, $1.y) }?.label ?? "-") last=\(cells.max { ($0.x, $0.y) < ($1.x, $1.y) }?.label ?? "-")")
            // In the band of section titles, so the drag scrolls rather than presses an emoji.
            let start = app.coordinate(withNormalizedOffset: .zero).withOffset(CGVector(dx: 340, dy: 553))
            start.press(
                forDuration: 0.05,
                thenDragTo: start.withOffset(CGVector(dx: -200, dy: 0)),
                withVelocity: 300,
                thenHoldForDuration: 0.8
            )
            Thread.sleep(forTimeInterval: 0.3)
        }

        let ordered = emoji.sorted { ($0.x, $0.y) < ($1.x, $1.y) }
        let sortedTitles = titles.sorted { $0.x < $1.x }
        let sections = sortedTitles.enumerated().map { index, title in
            let end = index + 1 < sortedTitles.count ? sortedTitles[index + 1].x : .infinity
            return Section(
                title: title.label,
                emoji: ordered.filter { $0.x >= title.x - 4 && $0.x < end - 4 }.map(\.label)
            )
        }
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted]
        try encoder.encode(sections).write(to: URL(fileURLWithPath: outputPath), options: .atomic)
    }

    /// The emoji keys and section titles on screen, by their frames' top-left corners.
    private static func visible(in app: XCUIApplication) throws -> (cells: [Seen], headers: [Seen]) {
        var cells: [Seen] = []
        var headers: [Seen] = []
        func collect(_ snapshot: XCUIElementSnapshot) {
            let frame = snapshot.frame
            if snapshot.elementType == .key, snapshot.identifier == snapshot.label, snapshot.label.isEmpty == false,
               frame.width < 40, frame.height < 40, frame.height > 20 {
                cells.append(Seen(x: frame.minX, y: frame.minY, label: snapshot.label))
            } else if snapshot.elementType == .other, snapshot.label.isEmpty == false,
                      snapshot.label == snapshot.label.uppercased(), snapshot.label.contains(where: \.isLetter),
                      frame.height == 30 {
                headers.append(Seen(x: frame.minX, y: frame.minY, label: snapshot.label))
            }
            snapshot.children.forEach(collect)
        }
        collect(try app.snapshot())
        return (cells, headers)
    }

    /// How far the grid scrolled since the emoji seen so far: the shift that most of the emoji
    /// on screen, which appear once in both, moved by.
    private static func offset(of cells: [Seen], against seen: [Seen]) throws -> CGFloat {
        guard seen.isEmpty == false else { return 0 }
        let seenOnce = Dictionary(grouping: seen, by: \.label).compactMapValues { $0.count == 1 ? $0[0] : nil }
        let shownOnce = Dictionary(grouping: cells, by: \.label).compactMapValues { $0.count == 1 ? $0[0] : nil }
        let shifts = shownOnce.compactMap { label, cell in
            seenOnce[label].map { (($0.x - cell.x) * 2).rounded() / 2 }
        }
        let counted = Dictionary(grouping: shifts, by: { $0 }).mapValues(\.count)
        let best = try XCTUnwrap(counted.max { $0.value < $1.value }, "no emoji in common with the last screen")
        XCTAssertGreaterThanOrEqual(best.value, 3, "too few emoji in common with the last screen to place it")
        return best.key
    }
}
