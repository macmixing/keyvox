import KeyVoxEmoji
import UIKit

/// The emoji page: the emoji in a grid that scrolls sideways through its sections, from one edge of
/// the keyboard to the other, over the bar with the letters key, the categories, and delete, as on
/// the system emoji keyboard. Each emoji shows and types in the skin tone last chosen for it;
/// holding one opens its skin-tone picker (`KeyboardEmojiPageView+SkinTones`).
final class KeyboardEmojiPageView: UIView {
    /// The system emoji keyboard on a 402-point-wide iPhone, in points, measured with
    /// Tools/AppleKeyboardBaseline (`EmojiKeyboardProbeTests`).
    enum Measured {
        /// Between the last row of emoji and the bar.
        static let barGap: CGFloat = 4
    }

    /// Matched to the system keyboard's screenshot from the same measurement.
    enum Drawn {
        /// The font size that draws an emoji as wide as the system keyboard does, for the size
        /// `KeyboardEmojiGridGeometry` gives it.
        static let emojiFontRatio: CGFloat = 0.98
    }

    var onEmojiSelected: ((String) -> Void)?
    /// Called with an emoji as it comes and the version of it chosen in its skin-tone picker.
    var onSkinToneChosen: ((_ emoji: String, _ version: String) -> Void)?
    /// Called the moment a held emoji's skin-tone picker opens.
    var onSkinTonePickerOpened: (() -> Void)?
    /// Called each time the finger moves onto another choice in a held emoji's skin-tone picker.
    var onSkinToneHighlighted: (() -> Void)?
    /// Called when a category is tapped, and each time another category reaches the grid's leading
    /// edge as a finger slides along the category bar.
    var onCategoryReached: (() -> Void)?
    /// Each emoji as it comes, by the skin-tone version last chosen for it.
    var chosenTones: [String: String] = [:] {
        didSet {
            guard chosenTones != oldValue else { return }
            collectionView.reloadData()
        }
    }
    /// The view a held emoji's skin-tone picker shows in, over the whole keyboard.
    var popupContainer: UIView?
    var onLetters: (() -> Void)? {
        get { categoryBar.onLetters }
        set { categoryBar.onLetters = newValue }
    }
    /// The key that leaves the page, shown as the keyboard's own key of that kind.
    var returnKey: KeyboardKeyKind = .abc {
        didSet {
            guard returnKey != oldValue else { return }
            categoryBar.showReturnKey(returnKey)
        }
    }
    var onDeleteBegan: (() -> Void)? {
        get { categoryBar.onDeleteBegan }
        set { categoryBar.onDeleteBegan = newValue }
    }
    var onDeleteEnded: (() -> Void)? {
        get { categoryBar.onDeleteEnded }
        set { categoryBar.onDeleteEnded = newValue }
    }

    let gridLayout = KeyboardEmojiGridLayout()
    lazy var collectionView = UICollectionView(frame: .zero, collectionViewLayout: gridLayout)
    private let categoryBar = KeyboardEmojiCategoryBar()
    private(set) var sections: [EmojiKeyboardSection] = []
    /// The Frequently Used emoji for a section of so many, and the catalog's sections after it.
    private var frequentlyUsedEmoji: (Int) -> [Emoji] = { _ in [] }
    private var catalog: [EmojiKeyboardSection] = []
    /// How many emoji the Frequently Used section was asked for, once the page has sections.
    private var frequentlyUsedCount: Int?
    let skinTonePicker = KeyboardEmojiSkinTonePickerView()
    let twoPersonPicker = KeyboardEmojiTwoPersonPickerView()
    /// The emoji held with its skin-tone picker open, the picker's layout, and the choice under the finger.
    var heldEmoji: (emoji: Emoji, layout: KeyboardEmojiSkinTonePickerLayout, choices: [String], choice: Int?)?
    private var categoryMemory = KeyboardEmojiCategoryMemory()
    private var shownCategory: EmojiKeyboardCategory?

    override init(frame: CGRect) {
        super.init(frame: frame)
        collectionView.translatesAutoresizingMaskIntoConstraints = false
        collectionView.backgroundColor = .clear
        collectionView.showsHorizontalScrollIndicator = false
        collectionView.alwaysBounceHorizontal = true
        // Prefetching keeps the emoji scrolled past, which a jump to a category never shows again:
        // measured, every jump added 36 emoji views and about 5.7 MB.
        collectionView.isPrefetchingEnabled = false
        // The grid scrolls only sideways; the blur iOS draws along a scrolling view's top edge
        // would only cover the top row under the search field.
        if #available(iOS 26.0, *) {
            collectionView.topEdgeEffect.isHidden = true
        }
        collectionView.dataSource = self
        collectionView.delegate = self
        collectionView.register(KeyboardEmojiCell.self, forCellWithReuseIdentifier: KeyboardEmojiCell.reuseIdentifier)
        categoryBar.translatesAutoresizingMaskIntoConstraints = false
        categoryBar.onCategory = { [weak self] category in
            self?.onCategoryReached?()
            self?.scroll(to: category)
        }
        categoryBar.onScrub = { [weak self] fraction in
            self?.scrub(to: fraction)
        }
        categoryBar.onScrubEnded = { [weak self] in
            self?.selectCategory()
        }
        addSubview(collectionView)
        addSubview(categoryBar)
        configureSkinTonePicker()
        NSLayoutConstraint.activate([
            collectionView.leadingAnchor.constraint(equalTo: leadingAnchor),
            collectionView.trailingAnchor.constraint(equalTo: trailingAnchor),
            collectionView.topAnchor.constraint(equalTo: topAnchor),
            collectionView.bottomAnchor.constraint(equalTo: categoryBar.topAnchor, constant: -Measured.barGap),
            // The bar keeps the keys' margins; the grid runs to the keyboard's edges.
            categoryBar.leadingAnchor.constraint(equalTo: leadingAnchor, constant: KeyboardStyle.horizontalPadding),
            categoryBar.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -KeyboardStyle.horizontalPadding),
            categoryBar.bottomAnchor.constraint(equalTo: bottomAnchor),
            categoryBar.heightAnchor.constraint(equalToConstant: KeyboardEmojiCategoryBar.Measured.height),
        ])
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    /// Shows the Frequently Used emoji `frequentlyUsed` gives for a section of whole columns, then
    /// `catalog`'s sections.
    func show(frequentlyUsed: @escaping (Int) -> [Emoji], catalog: [EmojiKeyboardSection]) {
        frequentlyUsedEmoji = frequentlyUsed
        self.catalog = catalog
        showFilledSections()
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        // The grid's rows are known once it is laid out, and whole columns depend on them.
        if let frequentlyUsedCount, frequentlyUsedCount != filledFrequentlyUsedCount {
            showFilledSections()
        }
    }

    /// The section's measured size, rounded up to whole columns of the grid as it is laid out.
    private var filledFrequentlyUsedCount: Int {
        KeyboardEmojiGridGeometry(gridHeight: collectionView.bounds.height).wholeColumnsCount(EmojiFrequentlyUsed.capacity)
    }

    private func showFilledSections() {
        let count = filledFrequentlyUsedCount
        frequentlyUsedCount = count
        show([EmojiKeyboardSection(category: .frequentlyUsed, emoji: frequentlyUsedEmoji(count))] + catalog)
    }

    private func show(_ sections: [EmojiKeyboardSection]) {
        guard sections != self.sections else { return }
        self.sections = sections
        gridLayout.emojiCounts = sections.map(\.emoji.count)
        categoryBar.setCategories(sections.map(\.category))
        collectionView.reloadData()
        collectionView.layoutIfNeeded()
        selectCategory()
    }

    /// The font the grid draws its emoji in.
    var emojiFont: UIFont {
        .systemFont(ofSize: gridLayout.geometry.emojiSize * Drawn.emojiFontRatio)
    }

    /// `emoji` as the page shows and types it: in the skin tone last chosen for it.
    func shown(_ emoji: Emoji) -> String {
        chosenTones[emoji.text] ?? emoji.text
    }

    private func scroll(to category: EmojiKeyboardCategory) {
        guard let section = sections.firstIndex(where: { $0.category == category }) else { return }
        let offset = categoryMemory.offset(
            forTapping: category,
            sectionStart: gridLayout.contentOffset(forSection: section),
            showing: shownCategory
        )
        let maximumOffset = max(0, collectionView.contentSize.width - collectionView.bounds.width)
        collectionView.setContentOffset(CGPoint(x: min(offset, maximumOffset), y: 0), animated: false)
        selectCategory()
    }

    /// Scrolls the grid as far along its emoji as a finger sliding along the category bar is along
    /// the bar, a column at a time, each where the grid rests, as on the system keyboard
    /// (`KeyboardEmojiCategoryBar+Scrub`).
    private func scrub(to fraction: CGFloat) {
        let maximumOffset = max(0, collectionView.contentSize.width - collectionView.bounds.width)
        let offset = gridLayout.restingContentOffset(near: fraction * maximumOffset)
        let shownBefore = shownCategory
        collectionView.setContentOffset(CGPoint(x: offset, y: 0), animated: false)
        if shownCategory != shownBefore {
            onCategoryReached?()
        }
    }

    /// Circles the category at the grid's leading edge and remembers where the grid is in it.
    private func selectCategory() {
        let offset = collectionView.contentOffset.x
        shownCategory = gridLayout.section(atContentOffset: offset).map { sections[$0].category }
        if let shownCategory {
            categoryMemory.gridScrolled(to: offset, showing: shownCategory)
        }
        categoryBar.select(shownCategory)
    }
}

extension KeyboardEmojiPageView: UICollectionViewDataSource {
    func numberOfSections(in _: UICollectionView) -> Int {
        sections.count
    }

    func collectionView(_: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        sections[section].emoji.count
    }

    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: KeyboardEmojiCell.reuseIdentifier, for: indexPath)
        (cell as? KeyboardEmojiCell)?.show(shown(sections[indexPath.section].emoji[indexPath.item]), font: emojiFont)
        return cell
    }
}

extension KeyboardEmojiPageView: UICollectionViewDelegate {
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        // Left selected, the emoji would not take a second tap.
        collectionView.deselectItem(at: indexPath, animated: false)
        onEmojiSelected?(shown(sections[indexPath.section].emoji[indexPath.item]))
    }

    func scrollViewDidScroll(_: UIScrollView) {
        selectCategory()
    }
}
