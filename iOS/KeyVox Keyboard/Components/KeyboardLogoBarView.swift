import UIKit

final class KeyboardLogoBarView: UIControl {
    enum VisualState: Equatable {
        case idle
        case waitingForApp
        case recording
        case transcribing
    }

    private enum Metrics {
        static let baseSize: CGFloat = 52
        static let barWidth: CGFloat = 4
        static let barSpacing: CGFloat = 4
        static let micSymbolSizeRatio: CGFloat = 0.60
        static let ringLineWidth: CGFloat = 2
        static let ripplePhaseStep: Double = 0.1
        static let quietPhaseStep: Double = 0.06
        static let phaseWrapPeriod: Double = .pi * 2
        static let shadowRadius: CGFloat = 10
        static let meterPollInterval: CFTimeInterval = 1.0 / 30.0
        static let barGlowRadius: CGFloat = 2.2
    }

    var liveMeterProvider: (() -> KeyVoxIPCLiveMeterSnapshot?)?

    var visualState: VisualState = .idle {
        didSet {
            guard oldValue != visualState else { return }
            if visualState != .recording {
                targetLevel = 0
                targetSignalState = .dead
            }
            updateAccessibility()
        }
    }

    override var intrinsicContentSize: CGSize {
        CGSize(width: KeyboardStyle.logoBarSize, height: KeyboardStyle.logoBarSize)
    }

    private let glowLayer = CAShapeLayer()
    private let backgroundLayer = CAShapeLayer()
    private let ringLayer = CAShapeLayer()
    private let barLayers = (0..<5).map { _ in CAGradientLayer() }
    private let microphoneImageView = UIImageView()

    private var displayLink: CADisplayLink?
    private var lastFrameTimestamp: CFTimeInterval?
    private var lastMeterPollTimestamp: CFTimeInterval?
    private var ripplePhase: Double = 0
    private var quietPhase: Double = 0
    private var displayedLevel: CGFloat = 0
    private var targetLevel: CGFloat = 0
    private var targetSignalState: KeyVoxIPCLiveMeterSignalState = .dead

    override init(frame: CGRect) {
        super.init(frame: frame)
        configureView()
        configureLayers()
        bringSubviewToFront(microphoneImageView)
        updateAccessibility()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    deinit {
        stopDisplayLink()
    }

    override func didMoveToWindow() {
        super.didMoveToWindow()
        if window == nil {
            stopDisplayLink()
        } else {
            startDisplayLinkIfNeeded()
        }
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

    private func startDisplayLinkIfNeeded() {
        guard displayLink == nil else { return }

        let displayLink = CADisplayLink(target: self, selector: #selector(handleDisplayLinkTick))
        displayLink.add(to: .main, forMode: .common)
        self.displayLink = displayLink
    }

    private func stopDisplayLink() {
        displayLink?.invalidate()
        displayLink = nil
        lastFrameTimestamp = nil
        lastMeterPollTimestamp = nil
    }

    @objc
    private func handleDisplayLinkTick(_ displayLink: CADisplayLink) {
        let previousTimestamp = lastFrameTimestamp ?? displayLink.timestamp
        let delta = min(max(displayLink.timestamp - previousTimestamp, 1.0 / 120.0), 1.0 / 20.0)
        lastFrameTimestamp = displayLink.timestamp

        ripplePhase = wrappedPhase(ripplePhase + Metrics.ripplePhaseStep * delta * 60)
        quietPhase = wrappedPhase(quietPhase + Metrics.quietPhaseStep * delta * 60)

        if visualState == .recording,
           lastMeterPollTimestamp == nil || displayLink.timestamp - (lastMeterPollTimestamp ?? 0) >= Metrics.meterPollInterval {
            lastMeterPollTimestamp = displayLink.timestamp
            let snapshot = liveMeterProvider?()
            targetLevel = CGFloat(snapshot?.level ?? 0)
            targetSignalState = snapshot?.signalState ?? .dead
        }

        let smoothing = CGFloat(min(delta * 16, 1))
        displayedLevel += (targetLevel - displayedLevel) * smoothing

        updateLayerFrames()
    }

    private func wrappedPhase(_ value: Double) -> Double {
        var wrapped = value
        while wrapped >= Metrics.phaseWrapPeriod {
            wrapped -= Metrics.phaseWrapPeriod
        }
        return wrapped
    }

    private func updateLayerFrames() {
        guard bounds.width > 0, bounds.height > 0 else { return }

        CATransaction.begin()
        CATransaction.setDisableActions(true)
        defer { CATransaction.commit() }

        let diameter = min(bounds.width, bounds.height)
        let scale = diameter / Metrics.baseSize
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

        backgroundLayer.path = circlePath
        backgroundLayer.fillColor = UIColor.black.withAlphaComponent(0.82).cgColor
        backgroundLayer.shadowColor = UIColor.black.cgColor
        backgroundLayer.shadowOpacity = 0.3
        backgroundLayer.shadowRadius = Metrics.shadowRadius * scale
        backgroundLayer.shadowOffset = .zero
        backgroundLayer.shadowPath = circlePath

        ringLayer.path = circlePath
        ringLayer.fillColor = UIColor.clear.cgColor
        ringLayer.strokeColor = UIColor.systemYellow.withAlphaComponent(0.6).cgColor
        ringLayer.lineWidth = Metrics.ringLineWidth * scale

        let showsMicrophoneSymbol = visualState == .idle || visualState == .waitingForApp
        microphoneImageView.isHidden = !showsMicrophoneSymbol
        microphoneImageView.alpha = visualState == .waitingForApp ? 0.72 : 1.0

        let barWidth = Metrics.barWidth * scale
        let barSpacing = Metrics.barSpacing * scale
        let totalBarWidth = (barWidth * CGFloat(barLayers.count)) + (barSpacing * CGFloat(barLayers.count - 1))
        let startX = bounds.midX - totalBarWidth / 2

        for (index, barLayer) in barLayers.enumerated() {
            barLayer.isHidden = showsMicrophoneSymbol
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

        if visualState == .transcribing {
            let waveOffset = ripplePhase + Double(index) * 0.8
            let rippleHeight = sin(waveOffset) * 0.5 + 0.5
            return flatHeight + (CGFloat(rippleHeight) * (9 * scale))
        }

        guard visualState == .recording else {
            return flatHeight
        }

        if targetSignalState == .dead {
            return flatHeight
        }

        if targetSignalState == .quiet {
            let quietWaveOffset = quietPhase + Double(index) * 0.8
            let quietRipple = (sin(quietWaveOffset) * 0.5) + 0.5
            let wiggleOffset = (quietPhase * 0.9) + Double(index) * 1.35
            let ambientWiggle = (sin(wiggleOffset) * 0.5) + 0.5
            let quietLevel = min(max(displayedLevel / 0.14, 0), 1)
            return flatHeight
                + (1.2 * scale)
                + (CGFloat(quietLevel) * (0.8 * scale))
                + (CGFloat(ambientWiggle) * (0.9 * scale))
                + (CGFloat(quietRipple) * (2.0 * scale))
        }

        let multipliers: [CGFloat] = [0.4, 0.7, 1.0, 0.7, 0.4]
        let dynamicHeight = displayedLevel * multipliers[index] * maxHeight
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
        switch visualState {
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
        }
    }
}
