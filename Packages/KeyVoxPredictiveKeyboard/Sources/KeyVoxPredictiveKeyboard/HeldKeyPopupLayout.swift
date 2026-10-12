import Foundation

/// Where a held key's popup goes and where each of its characters sits, as the system keyboard
/// lays them out: a row of cells above the key, the first character over the key and the rest
/// running outward toward the offer's side. When that side lacks the room, the row reaches the
/// keyboard's edge there and the rest spill to the other side; an offer of more than
/// `maximumCellsPerRow` characters takes two rows instead, the top row continuing the bottom one.
public struct HeldKeyPopupLayout: Sendable, Equatable {
    /// The most cells one row holds; a row narrows its cells to fit the keyboard up to this many.
    static let maximumCellsPerRow = 11

    /// The sizes the host draws the popup at.
    public struct Metrics: Sendable, Equatable {
        /// A cell's width, unless the row narrows its cells to fit the keyboard.
        public var cellWidth: CGFloat
        public var cellHeight: CGFloat
        /// The popup's margin around its cells.
        public var padding: CGFloat
        /// The space between the popup's bottom and the held key's top.
        public var gapAboveKey: CGFloat
        /// How far below the popup the finger may go before the popup closes without typing.
        public var closingDistance: CGFloat

        public init(cellWidth: CGFloat, cellHeight: CGFloat, padding: CGFloat, gapAboveKey: CGFloat, closingDistance: CGFloat) {
            self.cellWidth = cellWidth
            self.cellHeight = cellHeight
            self.padding = padding
            self.gapAboveKey = gapAboveKey
            self.closingDistance = closingDistance
        }
    }

    /// One character's place in the popup.
    public struct Cell: Sendable, Equatable {
        public let character: String
        public let frame: CGRect
    }

    /// The popup's frame.
    public let frame: CGRect
    /// The rows of cells, top first.
    public let rows: [[Cell]]
    /// The cell of the character the key types when the finger stays put, which starts selected.
    public let firstCell: Cell
    private let closingDistance: CGFloat

    /// - Parameters:
    ///   - offer: What the held key offers.
    ///   - keyFrame: The held key's frame.
    ///   - bounds: The keyboard's area, which the popup stays inside.
    public init(offer: HeldKeyCharacters.Offer, keyFrame: CGRect, bounds: CGRect, metrics: Metrics) {
        let arrangement = offer.characters.count > Self.maximumCellsPerRow
            ? Arrangement(twoRowsOf: offer, metrics: metrics)
            : Arrangement(rowOf: offer, keyMidX: keyFrame.midX, bounds: bounds, metrics: metrics)
        let rowHeight = metrics.cellHeight + 2 * metrics.padding
        let width = CGFloat(arrangement.columnCount) * arrangement.cellWidth + 2 * metrics.padding
        let height = CGFloat(arrangement.rows.count) * rowHeight
        let x: CGFloat
        switch arrangement.anchor {
        case .key:
            let centered = keyFrame.midX - metrics.padding - (CGFloat(arrangement.firstColumn) + 0.5) * arrangement.cellWidth
            x = max(bounds.minX, min(centered, bounds.maxX - width))
        case .leadingEdge:
            x = bounds.minX
        case .trailingEdge:
            x = bounds.maxX - width
        }
        let y = max(bounds.minY, keyFrame.minY - metrics.gapAboveKey - height)
        frame = CGRect(x: x, y: y, width: width, height: height)
        rows = arrangement.rows.enumerated().map { rowIndex, row in
            row.characters.enumerated().map { index, character in
                Cell(character: character, frame: CGRect(
                    x: x + metrics.padding + CGFloat(row.firstColumn + index) * arrangement.cellWidth,
                    y: y + CGFloat(rowIndex) * rowHeight + metrics.padding,
                    width: arrangement.cellWidth,
                    height: metrics.cellHeight
                ))
            }
        }
        firstCell = rows[rows.count - 1][arrangement.firstColumn]
        closingDistance = metrics.closingDistance
    }

    /// The cell a finger at `point` picks: in the row it is level with, the nearest across, or
    /// nil once it has gone far enough below the popup to close it.
    public func cell(at point: CGPoint) -> Cell? {
        guard point.y <= frame.maxY + closingDistance else { return nil }
        let rowHeight = frame.height / CGFloat(rows.count)
        let row = point.y < frame.minY + rowHeight ? rows[0] : rows[rows.count - 1]
        return row.min { abs($0.frame.midX - point.x) < abs($1.frame.midX - point.x) }
    }
}

/// Which characters go in which cells, before they are placed on the keyboard.
private struct Arrangement {
    enum Anchor {
        /// The first character's cell centers over the key, as far as the keyboard allows.
        case key
        /// The popup reaches the keyboard's edge on that side.
        case leadingEdge
        case trailingEdge
    }

    struct Row {
        let characters: [String]
        /// The column of the row's leftmost cell.
        let firstColumn: Int
    }

    /// The rows, top first.
    let rows: [Row]
    let columnCount: Int
    /// The column of the first character's cell in the bottom row.
    let firstColumn: Int
    let cellWidth: CGFloat
    let anchor: Anchor

    /// One row: the characters run toward the offer's side as far as it has room for, which
    /// counts a cell that would mostly fit, and the rest spill to the other side. The first
    /// character after the key's own takes the offer's side and the rest alternate, left first,
    /// until a side is full.
    init(rowOf offer: HeldKeyCharacters.Offer, keyMidX: CGFloat, bounds: CGRect, metrics: HeldKeyPopupLayout.Metrics) {
        let first = offer.characters[0]
        let others = Array(offer.characters.dropFirst())
        let towardRight = offer.direction == .right
        let cellWidth = min(metrics.cellWidth, (bounds.width - 2 * metrics.padding) / CGFloat(offer.characters.count))
        let room = towardRight
            ? (bounds.maxX - metrics.padding - cellWidth / 2 - keyMidX) / cellWidth
            : (keyMidX - cellWidth / 2 - metrics.padding - bounds.minX) / cellWidth
        let capacity = max(0, Int(room.rounded()))
        let characters: [String]
        if others.count <= capacity || offer.direction == .strictlyLeft {
            characters = towardRight ? [first] + others : others.reversed() + [first]
            firstColumn = towardRight ? 0 : others.count
            anchor = .key
        } else {
            let rightCapacity = towardRight ? capacity : others.count - capacity
            let leftCapacity = others.count - rightCapacity
            var right: [String] = []
            var left: [String] = []
            for (index, character) in others.enumerated() {
                let prefersRight = index == 0 ? towardRight : index.isMultiple(of: 2)
                if prefersRight ? right.count < rightCapacity : left.count == leftCapacity {
                    right.append(character)
                } else {
                    left.append(character)
                }
            }
            characters = left.reversed() + [first] + right
            firstColumn = left.count
            anchor = towardRight ? .trailingEdge : .leadingEdge
        }
        rows = [Row(characters: characters, firstColumn: 0)]
        columnCount = characters.count
        self.cellWidth = cellWidth
    }

    /// Two rows of full-width cells over the key: the bottom row holds the key's own character
    /// and the next ones outward toward the offer's side, the top row the rest in the same
    /// direction, starting above the key's.
    init(twoRowsOf offer: HeldKeyCharacters.Offer, metrics: HeldKeyPopupLayout.Metrics) {
        let towardRight = offer.direction == .right
        columnCount = (offer.characters.count + 1) / 2
        let bottom = Array(offer.characters.prefix(columnCount))
        let top = Array(offer.characters.dropFirst(columnCount))
        rows = towardRight
            ? [Row(characters: top, firstColumn: 0), Row(characters: bottom, firstColumn: 0)]
            : [Row(characters: top.reversed(), firstColumn: columnCount - top.count), Row(characters: bottom.reversed(), firstColumn: 0)]
        firstColumn = towardRight ? 0 : columnCount - 1
        cellWidth = metrics.cellWidth
        anchor = .key
    }
}
