import KeyVoxEmoji
import UIKit

/// The emoji search's results in one row that scrolls sideways, as on the system emoji keyboard.
/// Each result shows and types in the skin tone last chosen for it; holding one opens its skin-tone
/// picker (`KeyboardEmojiSearchResultsView+SkinTones`).
final class KeyboardEmojiSearchResultsView: UIView {
    private typealias Geometry = KeyboardEmojiSearchGeometry.Measured

    /// Matched to the system keyboard's screenshots: its search draws a thumbs-up about 35 points
    /// wide and 38 tall, and its skin-tone picker one about 30 wide.
    enum Drawn {
        static let emojiFontSize: CGFloat = 38
        static let pickerEmojiFontSize: CGFloat = 32
    }

    var onEmojiSelected: ((String) -> Void)?
    /// Called with an emoji as it comes and the version of it chosen in its skin-tone picker.
    var onSkinToneChosen: ((_ emoji: String, _ version: String) -> Void)?
    /// Called the moment a held result's skin-tone picker opens.
    var onSkinTonePickerOpened: (() -> Void)?
    /// Each emoji as it comes, by the skin-tone version last chosen for it.
    var chosenTones: [String: String] = [:] {
        didSet {
            guard chosenTones != oldValue else { return }
            collectionView.reloadData()
        }
    }
    /// The view a held result's skin-tone picker shows in, over the whole keyboard.
    var popupContainer: UIView?

    private(set) var results: [Emoji] = []
    private let flowLayout = UICollectionViewFlowLayout()
    lazy var collectionView = UICollectionView(frame: .zero, collectionViewLayout: flowLayout)
    let skinTonePicker = KeyboardEmojiSkinTonePickerView()
    /// Takes the next tap anywhere on the keyboard while a picker is open, to choose or close.
    let pickerTapCatcher = UIView()
    /// The result whose skin-tone picker is open, the picker's layout, and its choices.
    var heldResult: (emoji: Emoji, layout: KeyboardEmojiSearchSkinTonePickerLayout, choices: [String])?
    private let emojiFont = UIFont.systemFont(ofSize: Drawn.emojiFontSize)
    let pickerFont = UIFont.systemFont(ofSize: Drawn.pickerEmojiFontSize)

    override init(frame: CGRect) {
        super.init(frame: frame)
        flowLayout.scrollDirection = .horizontal
        flowLayout.itemSize = CGSize(width: Geometry.resultWidth, height: Geometry.resultsHeight)
        flowLayout.minimumLineSpacing = Geometry.resultPitch - Geometry.resultWidth
        flowLayout.sectionInset = UIEdgeInsets(top: 0, left: Geometry.resultsInset, bottom: 0, right: Geometry.resultsInset)
        collectionView.translatesAutoresizingMaskIntoConstraints = false
        collectionView.backgroundColor = .clear
        collectionView.showsHorizontalScrollIndicator = false
        collectionView.alwaysBounceHorizontal = true
        // As on the emoji page, prefetching would keep emoji scrolled past.
        collectionView.isPrefetchingEnabled = false
        // The system draws no haze over the results' edges; measured, the scroll view's own edge
        // effect blurred the emoji into the gap above them.
        if #available(iOS 26.0, *) {
            collectionView.topEdgeEffect.isHidden = true
            collectionView.bottomEdgeEffect.isHidden = true
            collectionView.leftEdgeEffect.isHidden = true
            collectionView.rightEdgeEffect.isHidden = true
        }
        collectionView.dataSource = self
        collectionView.delegate = self
        collectionView.register(KeyboardEmojiCell.self, forCellWithReuseIdentifier: KeyboardEmojiCell.reuseIdentifier)
        addSubview(collectionView)
        configureSkinTonePicker()
        NSLayoutConstraint.activate([
            collectionView.leadingAnchor.constraint(equalTo: leadingAnchor),
            collectionView.trailingAnchor.constraint(equalTo: trailingAnchor),
            collectionView.topAnchor.constraint(equalTo: topAnchor),
            collectionView.bottomAnchor.constraint(equalTo: bottomAnchor),
        ])
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    /// Shows `results` from the first.
    func show(_ results: [Emoji]) {
        closeSkinTonePicker()
        guard results != self.results else { return }
        self.results = results
        collectionView.reloadData()
        collectionView.setContentOffset(.zero, animated: false)
    }

    /// `emoji` as the results show and type it: in the skin tone last chosen for it.
    func shown(_ emoji: Emoji) -> String {
        chosenTones[emoji.text] ?? emoji.text
    }
}

extension KeyboardEmojiSearchResultsView: UICollectionViewDataSource {
    func collectionView(_: UICollectionView, numberOfItemsInSection _: Int) -> Int {
        results.count
    }

    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: KeyboardEmojiCell.reuseIdentifier, for: indexPath)
        (cell as? KeyboardEmojiCell)?.show(shown(results[indexPath.item]), font: emojiFont)
        return cell
    }
}

extension KeyboardEmojiSearchResultsView: UICollectionViewDelegate {
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        // Left selected, the result would not take a second tap.
        collectionView.deselectItem(at: indexPath, animated: false)
        onEmojiSelected?(shown(results[indexPath.item]))
    }
}
