import UIKit

/// Lays the emoji page's grid out where `KeyboardEmojiGridGeometry` puts each emoji and section
/// title, for the grid's height, keeping each section's title at the grid's leading edge while the
/// section shows there.
final class KeyboardEmojiGridLayout: UICollectionViewLayout {
    /// How many emoji each section shows, in order.
    var emojiCounts: [Int] = [] {
        didSet { invalidateLayout() }
    }

    /// How wide each section's title is drawn, in order.
    var titleWidths: [CGFloat] = [] {
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

    /// Scrolling moves the titles kept at the leading edge; a new height moves everything.
    override func shouldInvalidateLayout(forBoundsChange _: CGRect) -> Bool {
        true
    }

    override func invalidationContext(forBoundsChange newBounds: CGRect) -> UICollectionViewLayoutInvalidationContext {
        let context = super.invalidationContext(forBoundsChange: newBounds)
        if newBounds.height == preparedHeight {
            context.invalidateSupplementaryElements(
                ofKind: KeyboardEmojiSectionTitleView.kind,
                at: layout.titleFrames.indices.map { IndexPath(item: 0, section: $0) }
            )
        }
        return context
    }

    override func layoutAttributesForElements(in rect: CGRect) -> [UICollectionViewLayoutAttributes]? {
        var attributes: [UICollectionViewLayoutAttributes] = []
        for (section, frames) in layout.emojiFrames.enumerated() {
            let title = titleAttributes(section: section)
            if title.frame.intersects(rect) {
                attributes.append(title)
            }
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

    override func layoutAttributesForSupplementaryView(
        ofKind elementKind: String,
        at indexPath: IndexPath
    ) -> UICollectionViewLayoutAttributes? {
        guard elementKind == KeyboardEmojiSectionTitleView.kind,
              layout.titleFrames.indices.contains(indexPath.section) else {
            return nil
        }
        return titleAttributes(section: indexPath.section)
    }

    /// Where the grid scrolls to show `section` from its start.
    func contentOffset(forSection section: Int) -> CGFloat {
        layout.sectionOffsets.indices.contains(section) ? layout.sectionOffsets[section] : 0
    }

    /// The section showing at the grid's leading edge when scrolled to `offset`.
    func section(atContentOffset offset: CGFloat) -> Int? {
        layout.sectionOffsets.lastIndex { $0 <= offset + 1 }
    }

    private func titleAttributes(section: Int) -> UICollectionViewLayoutAttributes {
        let attributes = UICollectionViewLayoutAttributes(
            forSupplementaryViewOfKind: KeyboardEmojiSectionTitleView.kind,
            with: IndexPath(item: 0, section: section)
        )
        let width = titleWidths.indices.contains(section) ? titleWidths[section] : layout.titleFrames[section].width
        attributes.frame = layout.titleFrame(section: section, contentOffset: collectionView?.contentOffset.x ?? 0, width: width)
        attributes.zIndex = 1
        return attributes
    }
}
