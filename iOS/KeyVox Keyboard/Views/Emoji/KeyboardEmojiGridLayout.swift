import UIKit

/// Lays the emoji page's grid out where `KeyboardEmojiGridGeometry` puts each emoji, for the grid's
/// height.
final class KeyboardEmojiGridLayout: UICollectionViewLayout {
    /// How many emoji each section shows, in order.
    var emojiCounts: [Int] = [] {
        didSet { invalidateLayout() }
    }

    private(set) var geometry = KeyboardEmojiGridGeometry(gridHeight: 0)
    private var layout = KeyboardEmojiGridGeometry(gridHeight: 0).layout(emojiCounts: [])
    private var preparedHeight: CGFloat?
    private var preparedCounts: [Int]?

    override func prepare() {
        super.prepare()
        let height = collectionView?.bounds.height ?? 0
        guard height != preparedHeight || emojiCounts != preparedCounts else { return }
        preparedHeight = height
        preparedCounts = emojiCounts
        geometry = KeyboardEmojiGridGeometry(gridHeight: height)
        layout = geometry.layout(emojiCounts: emojiCounts)
    }

    override var collectionViewContentSize: CGSize {
        layout.contentSize
    }

    /// Scrolling moves nothing within the grid; a new size lays it out again.
    override func shouldInvalidateLayout(forBoundsChange newBounds: CGRect) -> Bool {
        newBounds.size != collectionView?.bounds.size
    }

    override func layoutAttributesForElements(in rect: CGRect) -> [UICollectionViewLayoutAttributes]? {
        var attributes: [UICollectionViewLayoutAttributes] = []
        for (section, frames) in layout.emojiFrames.enumerated() {
            for (item, frame) in frames.enumerated() where frame.intersects(rect) {
                let itemAttributes = UICollectionViewLayoutAttributes(forCellWith: IndexPath(item: item, section: section))
                itemAttributes.frame = frame
                attributes.append(itemAttributes)
            }
        }
        return attributes
    }

    override func layoutAttributesForItem(at indexPath: IndexPath) -> UICollectionViewLayoutAttributes? {
        guard layout.emojiFrames.indices.contains(indexPath.section),
              layout.emojiFrames[indexPath.section].indices.contains(indexPath.item) else {
            return nil
        }
        let attributes = UICollectionViewLayoutAttributes(forCellWith: indexPath)
        attributes.frame = layout.emojiFrames[indexPath.section][indexPath.item]
        return attributes
    }

    /// Brings the grid to rest on a column when a drag or flick ends, as the system keyboard does.
    override func targetContentOffset(
        forProposedContentOffset proposedContentOffset: CGPoint,
        withScrollingVelocity _: CGPoint
    ) -> CGPoint {
        CGPoint(x: restingContentOffset(near: proposedContentOffset.x), y: proposedContentOffset.y)
    }

    /// Where the grid rests near `offset`: on the column nearest there, within the grid's ends.
    func restingContentOffset(near offset: CGFloat) -> CGFloat {
        let maximum = max(0, layout.contentSize.width - (collectionView?.bounds.width ?? 0))
        return layout.restingContentOffset(near: offset, maximum: maximum)
    }

    /// Where the grid scrolls to show `section` from its start.
    func contentOffset(forSection section: Int) -> CGFloat {
        layout.sectionOffsets.indices.contains(section) ? layout.sectionOffsets[section] : 0
    }

    /// The section showing at the grid's leading edge when scrolled to `offset`.
    func section(atContentOffset offset: CGFloat) -> Int? {
        layout.sectionOffsets.lastIndex { $0 <= offset + 1 }
    }
}
