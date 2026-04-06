import UIKit

// NOTE: This file contains the proprietary KeyVox logo system
// referenced in LICENSE.md under Proprietary Assets and Branding.

final class KeyboardLogoBarView: UIControl {
    // Change this to resize the entire toolbar logo control.
    static let toolbarDiameter: CGFloat = 53

    private enum Metrics {
        static let barWidth: CGFloat = 4
        static let barSpacing: CGFloat = 4
        static let micSymbolSizeRatio: CGFloat = 0.65
        static let transportSymbolSizeRatio: CGFloat = 0.48
        static let ringLineWidth: CGFloat = 2
        static let shadowRadius: CGFloat = 5
        static let barGlowRadius: CGFloat = 1.5
    }

    override var intrinsicContentSize: CGSize {
        CGSize(width: Self.toolbarDiameter, height: Self.toolbarDiameter)
    }

    private let glowLayer = CAShapeLayer()
    private let backgroundLayer = CAShapeLayer()
    private let innerBorderLayer = CAShapeLayer()
    private let ringLayer = CAShapeLayer()
    private let transportProgressLayer = CAShapeLayer()
    private let barLayers = (0..<5).map { _ in CAGradientLayer() }
    private let microphoneImageView = UIImageView()
    private let microphoneBaseImage = UIImage(named: "microphone-icon")

    private var keyboardState: KeyboardState = .idle
    private var playbackProgress: CGFloat = 0
    private var indicatorPhase: AudioIndicatorPhase = .idle
    private var timelineState: AudioIndicatorTimelineState = .initial
    private var barsAreVisible = false
    private var isAnimatingActivationTransition = false
    private var lastRasterizedMicrophonePixelSize = CGSize.zero

    override init(frame: CGRect) {
        super.init(frame: frame)
        configureView()
        configureSizeConstraints()
        configureLayers()
        observeAppearanceChanges()
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
        let iconSide = min(bounds.width, bounds.height) * currentCenterIconSizeRatio()
        updateCenterIconImageIfNeeded(for: CGSize(width: iconSide, height: iconSide))
        microphoneImageView.bounds = CGRect(x: 0, y: 0, width: iconSide, height: iconSide)
        microphoneImageView.center = CGPoint(x: bounds.midX, y: bounds.midY)
        updateLayerFrames()
    }

    private func observeAppearanceChanges() {
        registerForTraitChanges([UITraitUserInterfaceStyle.self]) { (self: Self, _: UITraitCollection) in
            self.refreshMicrophoneImageForCurrentTraits()
        }
    }

    private func refreshMicrophoneImageForCurrentTraits() {
        lastRasterizedMicrophonePixelSize = .zero
        if bounds.width > 0, bounds.height > 0 {
            let iconSide = min(bounds.width, bounds.height) * currentCenterIconSizeRatio()
            updateCenterIconImageIfNeeded(for: CGSize(width: iconSide, height: iconSide))
        }
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
        microphoneImageView.tintColor = nil
        microphoneImageView.image = microphoneBaseImage?.withRenderingMode(.alwaysOriginal)
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
        layer.addSublayer(innerBorderLayer)
        layer.addSublayer(ringLayer)
        layer.addSublayer(transportProgressLayer)

        let indigo = UIColor.systemIndigo.cgColor
        let topIndigo = UIColor.systemIndigo.withAlphaComponent(0.9).cgColor
        for barLayer in barLayers {
            barLayer.colors = [indigo, topIndigo]
            barLayer.startPoint = CGPoint(x: 0.5, y: 1)
            barLayer.endPoint = CGPoint(x: 0.5, y: 0)
            barLayer.shadowColor = UIColor.systemYellow.cgColor
            barLayer.shadowOpacity = 0.95
            barLayer.shadowRadius = Metrics.barGlowRadius
            barLayer.shadowOffset = .zero
            layer.addSublayer(barLayer)
        }

        transportProgressLayer.fillColor = UIColor.clear.cgColor
        transportProgressLayer.strokeColor = UIColor.systemIndigo.cgColor
        transportProgressLayer.lineCap = .butt
        transportProgressLayer.strokeStart = 0
        transportProgressLayer.strokeEnd = 0
    }

    private func configureInitialPresentation() {
        microphoneImageView.isHidden = false
        microphoneImageView.alpha = 1
        microphoneImageView.transform = .identity
        barsAreVisible = false
        setBarsHidden(true)
        setBarOpacity(0)
    }

    func applyKeyboardState(_ state: KeyboardState) {
        let previousTransportSymbolName = transportSymbolName
        keyboardState = state
        if state.isTTSPlaybackActive == false {
            playbackProgress = 0
        }
        let nextTransportSymbolName = transportSymbolName

        if indicatorPhase != state.indicatorPhase {
            applyIndicatorPhase(state.indicatorPhase)
            return
        }

        updateAccessibility()
        guard previousTransportSymbolName != nextTransportSymbolName else { return }

        let iconSide = min(bounds.width, bounds.height) * currentCenterIconSizeRatio()
        updateCenterIconImageIfNeeded(for: CGSize(width: iconSide, height: iconSide))
        updateLayerFrames()
    }

    func applyPlaybackProgress(_ progress: CGFloat) {
        let clampedProgress = min(max(progress, 0), 1)
        let nextProgress = keyboardState.isTTSPlaybackActive ? clampedProgress : 0
        guard abs(playbackProgress - nextProgress) > 0.0001 else { return }
        playbackProgress = nextProgress
        updateLayerFrames()
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
        if transportSymbolName != nil {
            isAnimatingActivationTransition = false
            barsAreVisible = false
            setBarsHidden(true)
            setBarOpacity(0)
            microphoneImageView.isHidden = false
            microphoneImageView.alpha = 1
            microphoneImageView.transform = .identity
            let iconSide = min(bounds.width, bounds.height) * currentCenterIconSizeRatio()
            updateCenterIconImageIfNeeded(for: CGSize(width: iconSide, height: iconSide))
            return
        }

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

        let iconSide = min(bounds.width, bounds.height) * currentCenterIconSizeRatio()
        updateCenterIconImageIfNeeded(for: CGSize(width: iconSide, height: iconSide))
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
        let iconSide = min(bounds.width, bounds.height) * currentCenterIconSizeRatio()
        updateCenterIconImageIfNeeded(for: CGSize(width: iconSide, height: iconSide))

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
        glowLayer.shadowColor = UIColor.systemYellow.withAlphaComponent(0.25).cgColor
        glowLayer.shadowOpacity = 1
        glowLayer.shadowRadius = 5 * scale
        glowLayer.shadowOffset = .zero
        glowLayer.shadowPath = circlePath

        let logoBackgroundColor = UIColor { trait in
            trait.userInterfaceStyle == .dark
                ? UIColor.black.withAlphaComponent(0.82)
                : Self.compositedLightKeySurfaceColor()
        }.resolvedColor(with: traitCollection)

        backgroundLayer.path = circlePath
        backgroundLayer.fillColor = logoBackgroundColor.cgColor
        backgroundLayer.shadowColor = UIColor.black.cgColor
        backgroundLayer.shadowOpacity = traitCollection.userInterfaceStyle == .dark ? 0.3 : 0.15
        backgroundLayer.shadowRadius = Metrics.shadowRadius * scale
        backgroundLayer.shadowOffset = .zero
        backgroundLayer.shadowPath = circlePath

        let innerBorderLineWidth = max(0.9 * scale, 1 / (window?.screen.scale ?? UIScreen.main.scale))
        let innerBorderInset = ((Metrics.ringLineWidth * scale) / 2) + (innerBorderLineWidth / 2)
        let innerBorderRect = circleRect.insetBy(dx: innerBorderInset, dy: innerBorderInset)
        let innerBorderPath = UIBezierPath(ovalIn: innerBorderRect).cgPath
        let lightModeInnerBorderColor = KeyboardStyle.keyBorderColor
            .resolvedColor(with: traitCollection)
            .withAlphaComponent(0.42)

        innerBorderLayer.path = innerBorderPath
        innerBorderLayer.fillColor = UIColor.clear.cgColor
        innerBorderLayer.strokeColor = traitCollection.userInterfaceStyle == .light
            ? lightModeInnerBorderColor.cgColor
            : UIColor.clear.cgColor
        innerBorderLayer.lineWidth = innerBorderLineWidth

        ringLayer.path = circlePath
        ringLayer.fillColor = UIColor.clear.cgColor
        ringLayer.strokeColor = UIColor.systemYellow.withAlphaComponent(0.6).cgColor
        ringLayer.lineWidth = Metrics.ringLineWidth * scale

        let radius = circleRect.width / 2
        let arcCenter = CGPoint(x: circleRect.midX, y: circleRect.midY)
        let transportPath = UIBezierPath(
            arcCenter: arcCenter,
            radius: radius,
            startAngle: -.pi / 2,
            endAngle: (.pi * 3) / 2,
            clockwise: true
        ).cgPath
        transportProgressLayer.path = transportPath
        transportProgressLayer.lineWidth = Metrics.ringLineWidth * scale
        transportProgressLayer.strokeEnd = playbackProgress
        transportProgressLayer.isHidden = keyboardState.isTTSPlaybackActive == false

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

    private func updateMicrophoneImageIfNeeded(for size: CGSize) {
        guard size.width > 0, size.height > 0 else { return }
        guard let microphoneBaseImage else { return }

        let scale = window?.screen.scale ?? UIScreen.main.scale
        let pixelSize = CGSize(width: (size.width * scale).rounded(), height: (size.height * scale).rounded())
        guard pixelSize != lastRasterizedMicrophonePixelSize else { return }

        let rendererFormat = UIGraphicsImageRendererFormat(for: traitCollection)
        rendererFormat.opaque = false
        rendererFormat.scale = scale

        let tintColor = UIColor.systemIndigo
            .withAlphaComponent(0.85)
            .resolvedColor(with: traitCollection)

        let rasterizedImage = UIGraphicsImageRenderer(size: size, format: rendererFormat).image { _ in
            let rect = CGRect(origin: .zero, size: size)
            microphoneBaseImage.withRenderingMode(.alwaysOriginal).draw(in: rect)
            tintColor.setFill()
            UIRectFillUsingBlendMode(rect, .sourceIn)
        }

        lastRasterizedMicrophonePixelSize = pixelSize
        microphoneImageView.image = rasterizedImage.withRenderingMode(.alwaysOriginal)
    }

    private func updateCenterIconImageIfNeeded(for size: CGSize) {
        guard let transportSymbolName else {
            updateMicrophoneImageIfNeeded(for: size)
            return
        }

        lastRasterizedMicrophonePixelSize = .zero
        let pointSize = min(size.width, size.height)
        let configuration = UIImage.SymbolConfiguration(pointSize: pointSize, weight: .bold)
        let tintColor = UIColor.systemIndigo
            .withAlphaComponent(0.85)
            .resolvedColor(with: traitCollection)
        microphoneImageView.image = UIImage(systemName: transportSymbolName, withConfiguration: configuration)?
            .withTintColor(tintColor, renderingMode: .alwaysOriginal)
    }

    private func currentCenterIconSizeRatio() -> CGFloat {
        transportSymbolName == nil ? Metrics.micSymbolSizeRatio : Metrics.transportSymbolSizeRatio
    }

    private var transportSymbolName: String? {
        switch keyboardState {
        case .speaking:
            return "pause.fill"
        case .pausedSpeaking:
            return "play.fill"
        case .idle, .waitingForApp, .preparingPlayback, .recording, .transcribing:
            return nil
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

    private static func compositedLightKeySurfaceColor() -> UIColor {
        let overlay = KeyboardStyle.keyFillColor.resolvedColor(with: UITraitCollection(userInterfaceStyle: .light))
        var red: CGFloat = 0
        var green: CGFloat = 0
        var blue: CGFloat = 0
        var alpha: CGFloat = 0

        guard overlay.getRed(&red, green: &green, blue: &blue, alpha: &alpha) else {
            return KeyboardStyle.keyFillColor
        }

        let overlayAlpha: CGFloat = 0.3
        let base: CGFloat = 1.0
        return UIColor(
            red: (red * overlayAlpha) + (base * (1 - overlayAlpha)),
            green: (green * overlayAlpha) + (base * (1 - overlayAlpha)),
            blue: (blue * overlayAlpha) + (base * (1 - overlayAlpha)),
            alpha: 1
        )
    }

    private func updateAccessibility() {
        switch keyboardState {
        case .idle:
            accessibilityLabel = "Start recording"
            accessibilityValue = "Ready"
            isEnabled = true
        case .waitingForApp:
            accessibilityLabel = "Opening app"
            accessibilityValue = "Waiting"
            isEnabled = false
        case .recording:
            accessibilityLabel = "Stop recording and transcribe"
            accessibilityValue = "Recording"
            isEnabled = true
        case .transcribing:
            accessibilityLabel = "Transcribing"
            accessibilityValue = "Transcribing"
            isEnabled = false
        case .preparingPlayback:
            accessibilityLabel = "Opening app"
            accessibilityValue = "Waiting"
            isEnabled = false
        case .speaking:
            accessibilityLabel = "Pause playback"
            accessibilityValue = "Speaking"
            isEnabled = true
        case .pausedSpeaking:
            accessibilityLabel = "Resume playback"
            accessibilityValue = "Paused"
            isEnabled = true
        }
    }
}
