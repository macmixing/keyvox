import UIKit

final class FullAccessView: UIView {
    private enum Metrics {
        static let backButtonSize: CGFloat = 44
        static let backChevronPointSize: CGFloat = 15
        static let appIconSize: CGFloat = 24
    }

    var onBack: (() -> Void)?

    private let backButton = KeyboardHitTargetButton(type: .system)
    private let titleLabel = UILabel()
    private let trailingSpacer = UIView()
    private let scrollView = UIScrollView()
    private let contentContainerView = UIView()
    private let contentStack = UIStackView()

    override init(frame: CGRect) {
        super.init(frame: frame)
        configureView()
        configureHeader()
        configureContent()
        configureLayout()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func configureView() {
        backgroundColor = .clear
        translatesAutoresizingMaskIntoConstraints = false
    }

    private func configureHeader() {
        backButton.translatesAutoresizingMaskIntoConstraints = false
        backButton.backgroundColor = UIColor.white.withAlphaComponent(0.001)
        backButton.tintColor = .label
        backButton.setImage(
            UIImage(
                systemName: "chevron.left",
                withConfiguration: UIImage.SymbolConfiguration(pointSize: Metrics.backChevronPointSize, weight: .semibold)
            ),
            for: .normal
        )
        backButton.addTarget(self, action: #selector(handleBackTap), for: .touchUpInside)
        backButton.accessibilityLabel = "Back to keyboard"
        backButton.minimumHitTargetSize = CGSize(width: 44, height: 44)

        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        titleLabel.font = KeyboardTypography.font(20, variant: .medium)
        titleLabel.textColor = .label
        titleLabel.textAlignment = .center
        titleLabel.text = "How to Allow Full Access"
        titleLabel.isUserInteractionEnabled = false

        trailingSpacer.translatesAutoresizingMaskIntoConstraints = false
    }

    private func configureContent() {
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.showsVerticalScrollIndicator = false

        contentContainerView.translatesAutoresizingMaskIntoConstraints = false

        contentStack.translatesAutoresizingMaskIntoConstraints = false
        contentStack.axis = .vertical
        contentStack.alignment = .leading
        contentStack.distribution = .fill
        contentStack.spacing = 16

        addSubview(scrollView)
        scrollView.addSubview(contentContainerView)
        contentContainerView.addSubview(contentStack)

        contentStack.addArrangedSubview(makeStepRow(symbolName: "gearshape", text: "Open Settings"))
        contentStack.addArrangedSubview(makeStepRow(symbolName: "square.grid.2x2", text: "Tap Apps"))
        contentStack.addArrangedSubview(makeKeyVoxStepRow())
        contentStack.addArrangedSubview(makeStepRow(symbolName: "keyboard", text: "Tap Keyboards"))
        contentStack.addArrangedSubview(makeStepRow(symbolName: "checkmark.circle", text: "Turn on Allow Full Access"))
    }

    private func configureLayout() {
        addSubview(backButton)
        addSubview(titleLabel)
        addSubview(trailingSpacer)

        NSLayoutConstraint.activate([
            backButton.leadingAnchor.constraint(equalTo: safeAreaLayoutGuide.leadingAnchor, constant: 8),
            backButton.topAnchor.constraint(equalTo: safeAreaLayoutGuide.topAnchor, constant: 8),
            backButton.widthAnchor.constraint(equalToConstant: Metrics.backButtonSize),
            backButton.heightAnchor.constraint(equalToConstant: Metrics.backButtonSize),

            trailingSpacer.trailingAnchor.constraint(equalTo: safeAreaLayoutGuide.trailingAnchor, constant: -8),
            trailingSpacer.topAnchor.constraint(equalTo: backButton.topAnchor),
            trailingSpacer.widthAnchor.constraint(equalTo: backButton.widthAnchor),
            trailingSpacer.heightAnchor.constraint(equalTo: backButton.heightAnchor),

            titleLabel.leadingAnchor.constraint(equalTo: backButton.trailingAnchor, constant: 12),
            titleLabel.trailingAnchor.constraint(equalTo: trailingSpacer.leadingAnchor, constant: -12),
            titleLabel.centerYAnchor.constraint(equalTo: backButton.centerYAnchor),

            scrollView.leadingAnchor.constraint(equalTo: leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: trailingAnchor),
            scrollView.topAnchor.constraint(equalTo: backButton.bottomAnchor, constant: 8),
            scrollView.bottomAnchor.constraint(equalTo: safeAreaLayoutGuide.bottomAnchor),

            contentContainerView.leadingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.leadingAnchor),
            contentContainerView.trailingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.trailingAnchor),
            contentContainerView.topAnchor.constraint(equalTo: scrollView.contentLayoutGuide.topAnchor),
            contentContainerView.bottomAnchor.constraint(equalTo: scrollView.contentLayoutGuide.bottomAnchor),
            contentContainerView.widthAnchor.constraint(equalTo: scrollView.frameLayoutGuide.widthAnchor),

            contentStack.centerXAnchor.constraint(equalTo: contentContainerView.centerXAnchor),
            contentStack.topAnchor.constraint(equalTo: contentContainerView.topAnchor, constant: 12),
            contentStack.bottomAnchor.constraint(equalTo: contentContainerView.bottomAnchor, constant: -16),
            contentStack.leadingAnchor.constraint(greaterThanOrEqualTo: contentContainerView.leadingAnchor, constant: 20),
            contentStack.trailingAnchor.constraint(lessThanOrEqualTo: contentContainerView.trailingAnchor, constant: -20),
            contentStack.widthAnchor.constraint(lessThanOrEqualTo: contentContainerView.widthAnchor, constant: -40),
        ])
    }

    private func makeStepRow(symbolName: String, text: String) -> UIView {
        let symbolView = UIImageView()
        symbolView.translatesAutoresizingMaskIntoConstraints = false
        symbolView.contentMode = .scaleAspectFit
        symbolView.tintColor = .label
        symbolView.image = UIImage(
            systemName: symbolName,
            withConfiguration: UIImage.SymbolConfiguration(pointSize: 22, weight: .regular)
        )

        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.font = KeyboardTypography.font(17, variant: .light)
        label.textColor = .label
        label.numberOfLines = 0
        label.text = text

        let row = UIStackView(arrangedSubviews: [symbolView, label])
        row.translatesAutoresizingMaskIntoConstraints = false
        row.axis = .horizontal
        row.alignment = .center
        row.spacing = 14

        NSLayoutConstraint.activate([
            symbolView.widthAnchor.constraint(equalToConstant: 24),
            symbolView.heightAnchor.constraint(equalToConstant: 24),
        ])

        return row
    }

    private func makeKeyVoxStepRow() -> UIView {
        let symbolView = UIImageView()
        symbolView.translatesAutoresizingMaskIntoConstraints = false
        symbolView.contentMode = .scaleAspectFit
        symbolView.image = Self.keyVoxAppIconImage()
        symbolView.tintColor = .label

        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.textColor = .label
        label.numberOfLines = 0
        label.attributedText = keyVoxStepText()

        let row = UIStackView(arrangedSubviews: [symbolView, label])
        row.translatesAutoresizingMaskIntoConstraints = false
        row.axis = .horizontal
        row.alignment = .center
        row.spacing = 14

        NSLayoutConstraint.activate([
            symbolView.widthAnchor.constraint(equalToConstant: Metrics.appIconSize),
            symbolView.heightAnchor.constraint(equalToConstant: Metrics.appIconSize),
        ])

        return row
    }

    private func keyVoxStepText() -> NSAttributedString {
        let fullText = "Tap KeyVox"
        let attributedText = NSMutableAttributedString(
            string: fullText,
            attributes: [
                .foregroundColor: UIColor.label,
                .font: KeyboardTypography.font(17, variant: .light)
            ]
        )

        let keyVoxRange = (fullText as NSString).range(of: "KeyVox")
        attributedText.addAttributes(
            [.font: KeyboardTypography.font(17, variant: .medium)],
            range: keyVoxRange
        )

        return attributedText
    }

    @objc
    private func handleBackTap() {
        onBack?()
    }

    private static func keyVoxAppIconImage() -> UIImage? {
        UIImage(named: "app-icon-symbol", in: .main, with: nil)?.withRenderingMode(.alwaysTemplate)
    }
}
