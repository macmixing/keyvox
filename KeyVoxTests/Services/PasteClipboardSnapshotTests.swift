import AppKit
import XCTest
@testable import KeyVox

@MainActor
final class PasteClipboardSnapshotTests: XCTestCase {
    func testCaptureAndRestoreRoundTripForMultipleItems() {
        let pasteboard = makePasteboard()
        defer { pasteboard.clearContents() }

        let itemOne = NSPasteboardItem()
        itemOne.setString("first", forType: .string)
        itemOne.setData(Data([1, 2, 3]), forType: NSPasteboard.PasteboardType("com.keyvox.test.one"))

        let itemTwo = NSPasteboardItem()
        itemTwo.setString("second", forType: .string)

        XCTAssertTrue(pasteboard.writeObjects([itemOne, itemTwo]))

        let snapshot = PasteClipboardSnapshot.captureCurrentPasteboardItems(pasteboard)

        pasteboard.clearContents()
        pasteboard.setString("mutated", forType: .string)
        PasteClipboardSnapshot.restore(snapshot, to: pasteboard)

        let restored = pasteboard.pasteboardItems ?? []
        XCTAssertEqual(restored.count, 2)
        XCTAssertEqual(restored[0].string(forType: .string), "first")
        XCTAssertEqual(restored[0].data(forType: NSPasteboard.PasteboardType("com.keyvox.test.one")), Data([1, 2, 3]))
        XCTAssertEqual(restored[1].string(forType: .string), "second")
    }

    func testRestoreWithEmptySnapshotClearsPasteboard() {
        let pasteboard = makePasteboard()
        defer { pasteboard.clearContents() }

        pasteboard.clearContents()
        pasteboard.setString("to-clear", forType: .string)

        PasteClipboardSnapshot.restore([], to: pasteboard)

        let items = pasteboard.pasteboardItems ?? []
        XCTAssertTrue(items.isEmpty)
    }

    func testRestorePreservesMultipleTypesForSingleItem() {
        let pasteboard = makePasteboard()
        defer { pasteboard.clearContents() }

        let item = NSPasteboardItem()
        item.setString("plain", forType: .string)
        item.setData(Data("rich".utf8), forType: .rtf)
        XCTAssertTrue(pasteboard.writeObjects([item]))

        let snapshot = PasteClipboardSnapshot.captureCurrentPasteboardItems(pasteboard)
        pasteboard.clearContents()

        PasteClipboardSnapshot.restore(snapshot, to: pasteboard)

        let restoredItem = pasteboard.pasteboardItems?.first
        XCTAssertEqual(restoredItem?.string(forType: .string), "plain")
        XCTAssertEqual(restoredItem?.data(forType: .rtf), Data("rich".utf8))
    }

    private func makePasteboard() -> NSPasteboard {
        NSPasteboard(name: NSPasteboard.Name("KeyVoxTests.\(UUID().uuidString)"))
    }
}
