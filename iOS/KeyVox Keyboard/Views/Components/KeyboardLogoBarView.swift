import UIKit

final class KeyboardLogoBarView: UIControl {
    // Change this to resize the entire toolbar logo control.
    static let toolbarDiameter: CGFloat = 53

    private enum Metrics {
        static let barWidth: CGFloat = 4
        static let barSpacing: CGFloat = 4
        static let micSymbolSizeRatio: CGFloat = 0.60
        static let ringLineWidth: CGFloat = 2
        static let shadowRadius: CGFloat = 6
        static let barGlowRadius: CGFloat = 2.2
    }

    override var intrinsicContentSize: CGSize {
        CGSize(width: Self.toolbarDiameter, height: Self.toolbarDiameter)
    }

    private let glowLayer = CAShapeLayer()
    private let backgroundLayer = CAShapeLayer()
    private let ringLayer = CAShapeLayer()
    private let barLayers = (0..<5).map { _ in CAGradientLayer() }
    private let microphoneImageView = UIImageView()

    private var indicatorPhase: AudioIndicatorPhase = .idle
    private var timelineState: AudioIndicatorTimelineState = .initial
    private var barsAreVisible = false
    private var isAnimatingActivationTransition = false

    override init(frame: CGRect) {
        super.init(frame: frame)
        configureView()
        configureSizeConstraints()
        configureLayers()
        bringSubviewToFront(microphoneImageView)
        configureInitialPresentation()
        updateAccessibility()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        let micSide = min(bounds.width, bounds.height) * Metrics.micSymbolSizeRatio
        microphoneImageView.bounds = CGRect(x: 0, y: 0, width: micSide, height: micSide)
        microphoneImageView.center = CGPoint(x: bounds.midX, y: bounds.midY)
        updateLayerFrames()
    }

    override var isHighlighted: Bool {
        didSet {
            let scale: CGFloat = isHighlighted ? 0.96 : 1.0
            UIView.animate(
                withDuration: 0.14,
                delay: 0,
                options: [.beginFromCurrentState, .allowUserInteraction],
                animations: {
                    self.transform = CGAffineTransform(scaleX: scale, y: scale)
                }
            )
        }
    }

    private func configureView() {
        backgroundColor = .clear
        translatesAutoresizingMaskIntoConstraints = false
        accessibilityTraits = [.button]

        microphoneImageView.translatesAutoresizingMaskIntoConstraints = false
        microphoneImageView.contentMode = .scaleAspectFit
        microphoneImageView.tintColor = UIColor.systemIndigo.withAlphaComponent(0.95)
        microphoneImageView.image = UIImage(
            systemName: "mic.fill",
            withConfiguration: UIImage.SymbolConfiguration(pointSize: 20, weight: .semibold)
        )
        addSubview(microphoneImageView)
    }

    private func configureSizeConstraints() {
        NSLayoutConstraint.activate([
            widthAnchor.constraint(equalToConstant: Self.toolbarDiameter),
            heightAnchor.constraint(equalToConstant: Self.toolbarDiameter),
        ])
    }

    private func configureLayers() {
        layer.addSublayer(glowLayer)
        layer.addSublayer(backgroundLayer)
        layer.addSublayer(ringLayer)

        let indigo = UIColor.systemIndigo.cgColor
        let topIndigo = UIColor.systemIndigo.withAlphaComponent(0.9).cgColor
        for barLayer in barLayers {
            barLayer.colors = [indigo, topIndigo]
            barLayer.startPoint = CGPoint(x: 0.5, y: 1)
            barLayer.endPoint = CGPoint(x: 0.5, y: 0)
            barLayer.shadowColor = UIColor.systemYellow.withAlphaComponent(0.75).cgColor
            barLayer.shadowOpacity = 0.95
            barLayer.shadowRadius = Metrics.barGlowRadius
            barLayer.shadowOffset = .zero
            layer.addSublayer(barLayer)
        }
    }

    private func configureInitialPresentation() {
        microphoneImageView.isHidden = false
        microphoneImageView.alpha = 1
        microphoneImageView.transform = .identity
        barsAreVisible = false
        setBarsHidden(true)
        setBarOpacity(0)
    }

    func applyIndicatorPhase(_ phase: AudioIndicatorPhase) {
        guard indicatorPhase != phase else { return }
        let oldPhase = indicatorPhase
        indicatorPhase = phase
        updateAccessibility()
        handleIndicatorPhaseTransition(from: oldPhase, to: phase)
        updateLayerFrames()
    }

    func applyTimelineState(_ state: AudioIndicatorTimelineState) {
        timelineState = state
        updateLayerFrames()
    }

    private func handleIndicatorPhaseTransition(from oldPhase: AudioIndicatorPhase, to newPhase: AudioIndicatorPhase) {
        if newPhase == .idle {
            isAnimatingActivationTransition = false
            microphoneImageView.isHidden = false
            microphoneImageView.alpha = 0
            microphoneImageView.transform = CGAffineTransform(scaleX: 0.22, y: 0.22)

            UIView.animate(
                withDuration: 0.18,
                delay: 0,
                options: [.beginFromCurrentState, .allowUserInteraction, .curveEaseOut],
                animations: {
                    self.microphoneImageView.alpha = 1
                    self.microphoneImageView.transform = .identity
                }
            )

            animateBars(visible: false, duration: 0.12)
            return
        }

        if oldPhase == .idle {
            animateActivationTransitionIfNeeded()
            return
        }

        barsAreVisible = true
        setBarsHidden(false)
        setBarOpacity(1)

        guard !isAnimatingActivationTransition else { return }

        microphoneImageView.alpha = 0
        microphoneImageView.isHidden = true
        microphoneImageView.transform = .identity
    }

    private func animateActivationTransitionIfNeeded() {
        guard !isAnimatingActivationTransition else { return }
        isAnimatingActivationTransition = true

        barsAreVisible = true
        setBarsHidden(false)
        setBarOpacity(0.2)

        microphoneImageView.isHidden = false
        microphoneImageView.alpha = 1
        microphoneImageView.transform = .identity

        animateBarOpacity(to: 1, duration: 0.16)

        UIView.animate(
            withDuration: 0.18,
            delay: 0,
            options: [.beginFromCurrentState, .allowUserInteraction, .curveEaseInOut],
            animations: {
                self.microphoneImageView.alpha = 0
                self.microphoneImageView.transform = CGAffineTransform(scaleX: 0.18, y: 0.18)
            },
            completion: { _ in
                self.isAnimatingActivationTransition = false
                guard self.indicatorPhase != .idle else { return }
                self.microphoneImageView.isHidden = true
                self.microphoneImageView.alpha = 0
                self.microphoneImageView.transform = .identity
            }
        )
    }

    private func animateBars(visible: Bool, duration: CFTimeInterval) {
        barsAreVisible = visible
        setBarsHidden(false)
        animateBarOpacity(to: visible ? 1 : 0, duration: duration)

        guard !visible else { return }
        DispatchQueue.main.asyncAfter(deadline: .now() + duration) { [weak self] in
            guard let self, self.indicatorPhase == .idle else { return }
            self.setBarsHidden(true)
        }
    }

    private func setBarsHidden(_ hidden: Bool) {
        for barLayer in barLayers {
            barLayer.isHidden = hidden
        }
    }

    private func setBarOpacity(_ opacity: Float) {
        for barLayer in barLayers {
            barLayer.opacity = opacity
        }
    }

    private func animateBarOpacity(to opacity: Float, duration: CFTimeInterval) {
        CATransaction.begin()
        CATransaction.setAnimationDuration(duration)
        CATransaction.setAnimationTimingFunction(CAMediaTimingFunction(name: .easeInEaseOut))
        setBarOpacity(opacity)
        CATransaction.commit()
    }

    private func updateLayerFrames() {
        guard bounds.width > 0, bounds.height > 0 else { return }

        CATransaction.begin()
        CATransaction.setDisableActions(true)
        defer { CATransaction.commit() }

        let diameter = min(bounds.width, bounds.height)
        // 52 is the design-size baseline for the logo proportions.
        let scale = diameter / 52
        let circleInset = (Metrics.ringLineWidth * scale) / 2
        let circleRect = CGRect(
            x: bounds.midX - diameter / 2,
            y: bounds.midY - diameter / 2,
            width: diameter,
            height: diameter
        ).insetBy(dx: circleInset, dy: circleInset)
        let circlePath = UIBezierPath(ovalIn: circleRect).cgPath

        glowLayer.path = circlePath
        glowLayer.fillColor = UIColor.clear.cgColor
        glowLayer.strokeColor = UIColor.systemYellow.withAlphaComponent(0.45).cgColor
        glowLayer.lineWidth = Metrics.ringLineWidth * scale
        glowLayer.shadowColor = UIColor.systemYellow.withAlphaComponent(0.5).cgColor
        glowLayer.shadowOpacity = 1
        glowLayer.shadowRadius = 6 * scale
        glowLayer.shadowOffset = .zero
        glowLayer.shadowPath = circlePath

        let logoBackgroundColor = UIColor { trait in
            trait.userInterfaceStyle == .dark
                ? UIColor.black.withAlphaComponent(0.82)
                : UIColor.white.withAlphaComponent(0.96)
        }.resolvedColor(with: traitCollection)

        backgroundLayer.path = circlePath
        backgroundLayer.fillColor = logoBackgroundColor.cgColor
        backgroundLayer.shadowColor = UIColor.black.cgColor
        backgroundLayer.shadowOpacity = traitCollection.userInterfaceStyle == .dark ? 0.3 : 0.15
        backgroundLayer.shadowRadius = Metrics.shadowRadius * scale
        backgroundLayer.shadowOffset = .zero
        backgroundLayer.shadowPath = circlePath

        ringLayer.path = circlePath
        ringLayer.fillColor = UIColor.clear.cgColor
        ringLayer.strokeColor = UIColor.systemYellow.withAlphaComponent(0.6).cgColor
        ringLayer.lineWidth = Metrics.ringLineWidth * scale

        let barWidth = Metrics.barWidth * scale
        let barSpacing = Metrics.barSpacing * scale
        let totalBarWidth = (barWidth * CGFloat(barLayers.count)) + (barSpacing * CGFloat(barLayers.count - 1))
        let startX = bounds.midX - totalBarWidth / 2

        for (index, barLayer) in barLayers.enumerated() {
            barLayer.isHidden = !barsAreVisible
            let height = barHeight(for: index, scale: scale)
            let frame = pixelAligned(
                CGRect(
                x: startX + CGFloat(index) * (barWidth + barSpacing),
                y: bounds.midY - height / 2,
                width: barWidth,
                height: height
                )
            )
            barLayer.frame = frame
            barLayer.cornerRadius = frame.width / 2
            barLayer.shadowPath = UIBezierPath(
                roundedRect: barLayer.bounds,
                cornerRadius: barLayer.cornerRadius
            ).cgPath
        }
    }

    private func barHeight(for index: Int, scale: CGFloat) -> CGFloat {
        let minHeight: CGFloat = 6 * scale
        let flatHeight: CGFloat = 3 * scale
        let maxHeight: CGFloat = 30 * scale

        if indicatorPhase == .processing {
            let waveOffset = timelineState.processingPhase + Double(index) * 0.8
            let rippleHeight = sin(waveOffset) * 0.5 + 0.5
            return flatHeight + (CGFloat(rippleHeight) * (9 * scale))
        }

        guard indicatorPhase == .listening else {
            return flatHeight
        }

        if timelineState.signalState == .inactive {
            return flatHeight
        }

        if timelineState.signalState == .lowActivity {
            let quietWaveOffset = timelineState.lowActivityPhase + Double(index) * 0.8
            let quietRipple = (sin(quietWaveOffset) * 0.5) + 0.5
            let wiggleOffset = (timelineState.lowActivityPhase * 0.9) + Double(index) * 1.35
            let ambientWiggle = (sin(wiggleOffset) * 0.5) + 0.5
            let quietLevel = min(max(timelineState.displayedLevel / 0.14, 0), 1)
            return flatHeight
                + (1.2 * scale)
                + (CGFloat(quietLevel) * (0.8 * scale))
                + (CGFloat(ambientWiggle) * (0.9 * scale))
                + (CGFloat(quietRipple) * (2.0 * scale))
        }

        let multipliers: [CGFloat] = [0.4, 0.7, 1.0, 0.7, 0.4]
        let dynamicHeight = timelineState.displayedLevel * multipliers[index] * maxHeight
        return max(minHeight, dynamicHeight)
    }

    private func pixelAligned(_ rect: CGRect) -> CGRect {
        let scale = window?.screen.scale ?? UIScreen.main.scale
        guard scale > 0 else { return rect }

        func align(_ value: CGFloat) -> CGFloat {
            (value * scale).rounded() / scale
        }

        return CGRect(
            x: align(rect.origin.x),
            y: align(rect.origin.y),
            width: max(align(rect.size.width), 1 / scale),
            height: max(align(rect.size.height), 1 / scale)
        )
    }

    private func updateAccessibility() {
        switch indicatorPhase {
        case .idle:
            accessibilityLabel = "Start recording"
            accessibilityValue = "Ready"
            isEnabled = true
        case .waiting:
            accessibilityLabel = "Opening app"
            accessibilityValue = "Waiting"
            isEnabled = false
        case .listening:
            accessibilityLabel = "Stop recording and transcribe"
            accessibilityValue = "Recording"
            isEnabled = true
        case .processing:
            accessibilityLabel = "Transcribing"
            accessibilityValue = "Transcribing"
            isEnabled = false
        }
    }
}
