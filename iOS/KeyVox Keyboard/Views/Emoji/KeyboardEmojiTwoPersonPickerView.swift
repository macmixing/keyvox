import KeyVoxEmoji
import UIKit

/// The skin-tone picker of a held two-person emoji, as on the system emoji keyboard, recorded by
/// watching it (Tools/AppleKeyboardBaseline, `EmojiFrequentlyUsedProbeTests`): it stays open after
/// the finger lifts; a row of the first person's tones with the second in gray, a row of the second
/// person's with the first in gray, the tone tapped in each row highlighted, and below a divider the
/// emoji as it comes and the version chosen so far, each person not yet chosen in gray. Tapping the
/// emoji as it comes types it; tapping the chosen version types it once both people have a tone.
/// Tapping outside the panel closes it and types nothing. It opens on the version last chosen.
final class KeyboardEmojiTwoPersonPickerView: UIView {
    /// Measured in screenshots, light and dark.
    enum Measured {
        static let highlightColor = UIColor { trait in
            trait.userInterfaceStyle == .dark
                ? UIColor(red: 77 / 255, green: 77 / 255, blue: 77 / 255, alpha: 1)
                : UIColor(red: 238 / 255, green: 238 / 255, blue: 239 / 255, alpha: 1)
        }
        static let dividerColor = UIColor { trait in
            trait.userInterfaceStyle == .dark
                ? UIColor(red: 84 / 255, green: 84 / 255, blue: 84 / 255, alpha: 1)
                : UIColor(red: 238 / 255, green: 238 / 255, blue: 239 / 255, alpha: 1)
        }
    }

    /// Called with the version to type, after which the picker has closed.
    var onChosen: ((String) -> Void)?
    /// Called when a tap outside the panel closed the picker.
    var onDismissed: (() -> Void)?

    private let shapeLayer = CAShapeLayer()
    private let dividerView = UIView()
    private let firstHighlight = UIView()
    private let secondHighlight = UIView()
    private var firstToneViews: [UIImageView] = []
    private var secondToneViews: [UIImageView] = []
    private let plainLabel = UILabel()
    private let chosenView = UIImageView()
    private var layout: KeyboardEmojiTwoPersonPickerLayout?
    private var tones: EmojiTwoPersonTones?
    private var plain = ""
    private var bottomFont = UIFont.systemFont(ofSize: 1)
    private var firstTone: Int?
    private var secondTone: Int?
    private var panelFill: UIColor = .clear

    override init(frame: CGRect) {
        super.init(frame: frame)
        isHidden = true
        layer.addSublayer(shapeLayer)
        addSubview(dividerView)
        for highlight in [firstHighlight, secondHighlight] {
            highlight.layer.cornerRadius = KeyboardEmojiTwoPersonPickerLayout.Measured.highlightCornerRadius
            addSubview(highlight)
        }
        for _ in 0..<EmojiTwoPersonTones.toneCount {
            let first = UIImageView()
            let second = UIImageView()
            firstToneViews.append(first)
            secondToneViews.append(second)
            addSubview(first)
            addSubview(second)
        }
        plainLabel.textAlignment = .center
        addSubview(plainLabel)
        addSubview(chosenView)
        registerForTraitChanges([UITraitUserInterfaceStyle.self]) { (self: Self, _: UITraitCollection) in
            self.applyColors()
        }
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    var isPresented: Bool { isHidden == false }

    /// Shows the picker of `emoji` laid out by `layout`, in this view's coordinates, its rows in
    /// `font` and its bottom row larger, opened on `chosenVersion` when it is one of the emoji's.
    func present(
        _ emoji: Emoji,
        tones: EmojiTwoPersonTones,
        chosenVersion: String?,
        layout: KeyboardEmojiTwoPersonPickerLayout,
        font: UIFont,
        style: KeyboardEmojiSkinTonePickerView.Style
    ) {
        self.layout = layout
        self.tones = tones
        plain = emoji.text
        bottomFont = font.withSize(font.pointSize * KeyboardEmojiTwoPersonPickerLayout.Measured.bottomEmojiScale)
        let chosen = chosenVersion.flatMap(tones.tones(of:))
        firstTone = chosen?.first
        secondTone = chosen?.second
        shapeLayer.path = KeyboardEmojiPickerPanelShape.path(
            panel: layout.panelFrame,
            stem: layout.stemFrame,
            panelCornerRadius: style.panelCornerRadius,
            stemCornerRadius: style.stemCornerRadius
        ).cgPath
        shapeLayer.fillColor = style.fillColor.resolvedColor(with: traitCollection).cgColor
        panelFill = style.fillColor
        dividerView.frame = layout.dividerFrame
        let scale = traitCollection.displayScale
        for tone in 0..<EmojiTwoPersonTones.toneCount {
            let (others, otherComparison) = Self.contrastingTones(besides: tone)
            firstToneViews[tone].image = tones.version(first: tone, second: others).flatMap { version in
                KeyboardEmojiSilhouetteRenderer.image(
                    of: version,
                    graying: tones.version(first: tone, second: otherComparison).map { [$0] } ?? [],
                    font: font,
                    scale: scale
                )
            }
            secondToneViews[tone].image = tones.version(first: others, second: tone).flatMap { version in
                KeyboardEmojiSilhouetteRenderer.image(
                    of: version,
                    graying: tones.version(first: otherComparison, second: tone).map { [$0] } ?? [],
                    font: font,
                    scale: scale
                )
            }
            place(firstToneViews[tone], at: layout.firstToneCenters[tone])
            place(secondToneViews[tone], at: layout.secondToneCenters[tone])
        }
        plainLabel.text = emoji.text
        plainLabel.font = bottomFont
        plainLabel.sizeToFit()
        plainLabel.center = layout.plainCenter
        showChoice()
        applyColors()
        isHidden = false
    }

    func dismiss() {
        isHidden = true
        layout = nil
        tones = nil
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let layout, let tones, let point = touches.first?.location(in: self) else { return }
        switch layout.target(at: point) {
        case let .firstTone(tone):
            firstTone = tone
            showChoice()
        case let .secondTone(tone):
            secondTone = tone
            showChoice()
        case .plain:
            choose(plain)
        case .chosen:
            if let firstTone, let secondTone, let version = tones.version(first: firstTone, second: secondTone) {
                choose(version)
            }
        case .panel:
            break
        case nil:
            dismiss()
            onDismissed?()
        }
    }

    private func choose(_ version: String) {
        dismiss()
        onChosen?(version)
    }

    /// Highlights the tones chosen so far and shows the version they make, each person without a
    /// tone in gray.
    private func showChoice() {
        guard let layout, let tones else { return }
        let size = KeyboardEmojiTwoPersonPickerLayout.Measured.highlightSize
        for (highlight, tone, centers) in [(firstHighlight, firstTone, layout.firstToneCenters), (secondHighlight, secondTone, layout.secondToneCenters)] {
            highlight.isHidden = tone == nil
            if let tone {
                highlight.frame = CGRect(x: centers[tone].x - (size / 2), y: centers[tone].y - (size / 2), width: size, height: size)
            }
        }
        let scale = traitCollection.displayScale
        let image: UIImage?
        switch (firstTone, secondTone) {
        case let (first?, second?):
            image = tones.version(first: first, second: second).flatMap {
                KeyboardEmojiSilhouetteRenderer.image(of: $0, graying: [], font: bottomFont, scale: scale)
            }
        case let (first?, nil):
            let (other, comparison) = Self.contrastingTones(besides: first)
            image = tones.version(first: first, second: other).flatMap { version in
                KeyboardEmojiSilhouetteRenderer.image(
                    of: version,
                    graying: tones.version(first: first, second: comparison).map { [$0] } ?? [],
                    font: bottomFont,
                    scale: scale
                )
            }
        case let (nil, second?):
            let (other, comparison) = Self.contrastingTones(besides: second)
            image = tones.version(first: other, second: second).flatMap { version in
                KeyboardEmojiSilhouetteRenderer.image(
                    of: version,
                    graying: tones.version(first: comparison, second: second).map { [$0] } ?? [],
                    font: bottomFont,
                    scale: scale
                )
            }
        case (nil, nil):
            // The lightest and darkest tones each way show both people.
            image = tones.version(first: 0, second: EmojiTwoPersonTones.toneCount - 1).flatMap { version in
                KeyboardEmojiSilhouetteRenderer.image(
                    of: version,
                    graying: [
                        tones.version(first: EmojiTwoPersonTones.toneCount - 2, second: EmojiTwoPersonTones.toneCount - 1),
                        tones.version(first: 0, second: 1),
                    ].compactMap { $0 },
                    font: bottomFont,
                    scale: scale
                )
            }
        }
        chosenView.image = image
        place(chosenView, at: layout.chosenCenter)
    }

    /// Two tones other than `tone`, as far apart as they can be, to draw a person in to find what
    /// changes with that person's tone; the one-tone version, both people in `tone`, can be drawn
    /// differently.
    private static func contrastingTones(besides tone: Int) -> (Int, Int) {
        let last = EmojiTwoPersonTones.toneCount - 1
        switch tone {
        case 0: return (1, last)
        case last: return (0, last - 1)
        default: return (0, last)
        }
    }

    private func place(_ view: UIImageView, at center: CGPoint) {
        view.sizeToFit()
        view.center = center
    }

    private func applyColors() {
        shapeLayer.fillColor = panelFill.resolvedColor(with: traitCollection).cgColor
        dividerView.backgroundColor = Measured.dividerColor.resolvedColor(with: traitCollection)
        for highlight in [firstHighlight, secondHighlight] {
            highlight.backgroundColor = Measured.highlightColor.resolvedColor(with: traitCollection)
        }
    }
}
