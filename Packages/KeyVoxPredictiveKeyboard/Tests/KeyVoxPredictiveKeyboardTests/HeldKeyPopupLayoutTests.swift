import CoreGraphics
import XCTest
@testable import KeyVoxPredictiveKeyboard

/// The popups the system keyboard laid out on a 402-point-wide iPhone, upright and on its side,
/// with each offer's characters numbered in order, so "0" is what the key types.
final class HeldKeyPopupLayoutTests: XCTestCase {
    private let uprightBounds = CGRect(x: 0, y: 0, width: 402, height: 226)
    private let sidewaysBounds = CGRect(x: 75, y: 0, width: 724, height: 177)
    private let uprightMetrics = HeldKeyPopupLayout.Metrics(cellWidth: 37.4, cellHeight: 47, padding: 10.2, gapAboveKey: 4.4, closingDistance: 87.8)
    private let sidewaysMetrics = HeldKeyPopupLayout.Metrics(cellWidth: 70.2, cellHeight: 47, padding: 10.2, gapAboveKey: 3.3, closingDistance: 93.3)

    func testRowTowardRightReachesTheEdgeAndSpillsLeft() {
        // The e key: ë é e è ê ě ẽ ē ė ę.
        let layout = layout(count: 10, .right, keyMidX: 102.3)
        XCTAssertEqual(characters(layout), [["4", "2", "0", "1", "3", "5", "6", "7", "8", "9"]])
        XCTAssertEqual(layout.frame.maxX, uprightBounds.maxX, accuracy: 0.01)
        XCTAssertEqual(layout.firstCell.character, "0")
    }

    func testRowTowardLeftSpillsRightAlternatingAfterTheFirst() {
        // The i key: į ı ī ĩ ï í ì i î ǐ.
        let layout = layout(count: 10, .left, keyMidX: 299.9)
        XCTAssertEqual(characters(layout), [["9", "8", "7", "6", "4", "2", "1", "0", "3", "5"]])
        XCTAssertEqual(layout.frame.minX, uprightBounds.minX, accuracy: 0.01)
    }

    func testElevenCellsNarrowToFitTheKeyboard() {
        // The u key: ų ů ű ũ ü ú ù u û ǔ ū.
        let u = layout(count: 11, .left, keyMidX: 259.9)
        XCTAssertEqual(characters(u), [["10", "9", "8", "6", "4", "2", "1", "0", "3", "5", "7"]])
        XCTAssertEqual(u.frame.minX, uprightBounds.minX, accuracy: 0.01)
        XCTAssertEqual(u.frame.maxX, uprightBounds.maxX, accuracy: 0.01)
        // The o key: ő ō õ ø œ ǒ ö ó ò o ô.
        XCTAssertEqual(characters(layout(count: 11, .left, keyMidX: 338.9)), [["10", "9", "8", "7", "6", "5", "4", "2", "1", "0", "3"]])
    }

    func testRowWithEqualSidesAlternates() {
        // The $ key: ₽ ¥ € $ ¢ £ ₩.
        let layout = layout(count: 7, .right, keyMidX: 259.9)
        XCTAssertEqual(characters(layout), [["6", "4", "2", "0", "1", "3", "5"]])
        XCTAssertEqual(layout.frame.maxX, uprightBounds.maxX, accuracy: 0.01)
    }

    func testRowWithRoomStaysOnItsSideOverTheKey() {
        let s = layout(count: 6, .right, keyMidX: 82.5)
        XCTAssertEqual(characters(s), [["0", "1", "2", "3", "4", "5"]])
        XCTAssertEqual(s.firstCell.frame.midX, 82.5, accuracy: 0.01)
        let y = layout(count: 4, .left, keyMidX: 220.9)
        XCTAssertEqual(characters(y), [["3", "2", "1", "0"]])
        XCTAssertEqual(y.firstCell.frame.midX, 220.9, accuracy: 0.01)
    }

    func testRowAtTheEdgeShiftsInside() {
        // The 0 key: ° 0.
        let layout = layout(count: 2, .left, keyMidX: 378.9)
        XCTAssertEqual(characters(layout), [["1", "0"]])
        XCTAssertEqual(layout.frame.maxX, uprightBounds.maxX, accuracy: 0.01)
    }

    func testStrictlyLeftNeverSpillsRight() {
        let layout = layout(count: 6, .strictlyLeft, keyMidX: 60)
        XCTAssertEqual(characters(layout), [["5", "4", "3", "2", "1", "0"]])
        XCTAssertEqual(layout.frame.minX, uprightBounds.minX, accuracy: 0.01)
    }

    func testTwelveCharactersTakeTwoRows() {
        // The a key: æ ã å ā ă ą over a à á â ä ǎ.
        let layout = layout(count: 12, .right, keyMidX: 42.6)
        XCTAssertEqual(characters(layout), [["6", "7", "8", "9", "10", "11"], ["0", "1", "2", "3", "4", "5"]])
        XCTAssertEqual(layout.firstCell.frame.midX, 42.6, accuracy: 0.01)
        XCTAssertEqual(layout.frame.height, 2 * (47 + 2 * 10.2), accuracy: 0.01)
    }

    func testSidewaysRowsSpillWithinTheKeyboard() {
        let e = layout(count: 10, .right, keyMidX: 257.5, bounds: sidewaysBounds, metrics: sidewaysMetrics)
        XCTAssertEqual(characters(e), [["4", "2", "0", "1", "3", "5", "6", "7", "8", "9"]])
        XCTAssertEqual(e.frame.maxX, sidewaysBounds.maxX, accuracy: 0.01)
        let i = layout(count: 10, .left, keyMidX: 618.5, bounds: sidewaysBounds, metrics: sidewaysMetrics)
        XCTAssertEqual(characters(i), [["9", "8", "7", "6", "4", "2", "1", "0", "3", "5"]])
        XCTAssertEqual(i.frame.minX, sidewaysBounds.minX, accuracy: 0.01)
    }

    func testFingerPicksTheNearestCellInItsRow() {
        let layout = layout(count: 10, .right, keyMidX: 102.3)
        let row = layout.rows[0]
        XCTAssertEqual(layout.cell(at: CGPoint(x: row[3].frame.midX + 10, y: layout.frame.midY)), row[3])
        XCTAssertEqual(layout.cell(at: CGPoint(x: uprightBounds.minX - 50, y: layout.frame.minY - 100)), row[0])
        XCTAssertEqual(layout.cell(at: CGPoint(x: uprightBounds.maxX + 50, y: layout.frame.maxY + 87)), row[9])
        XCTAssertNil(layout.cell(at: CGPoint(x: row[3].frame.midX, y: layout.frame.maxY + 88)))
    }

    func testFingerPicksTheRowItIsLevelWith() {
        let layout = layout(count: 12, .right, keyMidX: 42.6)
        let middle = layout.frame.midY
        XCTAssertEqual(layout.cell(at: CGPoint(x: layout.rows[0][2].frame.midX, y: middle - 1)), layout.rows[0][2])
        XCTAssertEqual(layout.cell(at: CGPoint(x: layout.rows[1][2].frame.midX, y: middle + 1)), layout.rows[1][2])
    }

    private func layout(
        count: Int,
        _ direction: HeldKeyCharacters.Direction,
        keyMidX: CGFloat,
        bounds: CGRect? = nil,
        metrics: HeldKeyPopupLayout.Metrics? = nil
    ) -> HeldKeyPopupLayout {
        let offer = HeldKeyCharacters.Offer(characters: (0..<count).map(String.init), direction: direction)
        let keyFrame = CGRect(x: keyMidX - 17, y: 160, width: 34, height: 41)
        return HeldKeyPopupLayout(offer: offer, keyFrame: keyFrame, bounds: bounds ?? uprightBounds, metrics: metrics ?? uprightMetrics)
    }

    private func characters(_ layout: HeldKeyPopupLayout) -> [[String]] {
        layout.rows.map { $0.map(\.character) }
    }
}
