import KeyVoxKeyboardThemes
import KeyVoxPredictiveKeyboard
import QuartzCore
import UIKit

/// The trail a swipe leaves across the letter keys, drawn as the keyboard's theme draws it
/// (`KeyboardThemeSwipeTrail`): full width at the finger, tapering and fading behind it over a
/// softer glow, and fading away once the finger lifts.
///
/// The trail is a ribbon whose width follows each point's age, cut into a fixed set of shape
/// layers by age, the newest the most opaque; neighboring bands share their edge exactly, so
/// the ribbon reads as one smooth stroke, rounded at the finger. Each screen refresh while a
/// trail shows only replaces the layers' paths, with Core Animation's implicit animations off.
final class KeyboardSwipeTrailView: UIView {
    private struct Point {
        let location: CGPoint
        let time: TimeInterval
    }

    /// How many age bands the stroke and the glow are drawn in.
    private static let strokeBands = 12
    private static let glowBands = 6
    /// Samples closer than this to the last kept one add nothing to the drawn ribbon, in points.
    private static let minimumSpacing: CGFloat = 1

    private let glowLayers: [CAShapeLayer]
    private let strokeLayers: [CAShapeLayer]
    private var points: [Point] = []
    private var displayLink: CADisplayLink?
    private var liftTime: TimeInterval?
    private var style: KeyboardThemeSwipeTrail?

    override init(frame: CGRect) {
        glowLayers = (0..<Self.glowBands).map { _ in Self.bandLayer() }
        strokeLayers = (0..<Self.strokeBands).map { _ in Self.bandLayer() }
        super.init(frame: frame)
        isUserInteractionEnabled = false
        backgroundColor = .clear
        (glowLayers + strokeLayers).forEach(layer.addSublayer)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    deinit {
        displayLink?.invalidate()
    }

    /// Starts a trail along `path`, in this view's coordinates, in the theme's style.
    func begin(with path: [SwipeTouchSample]) {
        let style = traitCollection.keyboardThemePalette.swipeTrail
        self.style = style
        let color = style.color.resolvedColor(with: traitCollection).cgColor
        let glow = style.glowColor.resolvedColor(with: traitCollection).cgColor
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        for (band, layer) in strokeLayers.enumerated() {
            layer.fillColor = color
            layer.opacity = Self.opacity(of: band, bands: Self.strokeBands)
        }
        for (band, layer) in glowLayers.enumerated() {
            layer.fillColor = glow
            layer.opacity = Self.opacity(of: band, bands: Self.glowBands)
        }
        CATransaction.commit()
        points = []
        liftTime = nil
        extend(with: path)
        startRefreshing()
        render()
    }

    func extend(with samples: [SwipeTouchSample]) {
        for sample in samples {
            if let last = points.last,
               hypot(sample.location.x - last.location.x, sample.location.y - last.location.y) < Self.minimumSpacing {
                continue
            }
            points.append(Point(location: sample.location, time: sample.timestamp))
        }
    }

    /// The finger lifted: what is left fades out over the theme's lift fade.
    func lift() {
        guard style != nil else { return }
        liftTime = ProcessInfo.processInfo.systemUptime
    }

    /// Removes the trail at once.
    func cancel() {
        stopRefreshing()
        points = []
        liftTime = nil
        style = nil
        clearPaths()
    }

    private func startRefreshing() {
        guard displayLink == nil else { return }
        let link = CADisplayLink(target: RefreshTarget(self), selector: #selector(RefreshTarget.refresh))
        link.add(to: .main, forMode: .common)
        displayLink = link
    }

    private func stopRefreshing() {
        displayLink?.invalidate()
        displayLink = nil
    }

    fileprivate func render() {
        guard let style else { return cancel() }
        let now = ProcessInfo.processInfo.systemUptime
        // Once lifted, the trail ages faster, so all of it is gone within the lift fade.
        let liftAging = liftTime.map { (now - $0) * (style.fadeDuration / style.liftFadeDuration - 1) } ?? 0
        guard let firstVisible = points.firstIndex(where: { now - $0.time + liftAging < style.fadeDuration }) else {
            if liftTime != nil { return cancel() }
            return clearPaths()
        }
        points.removeFirst(max(0, firstVisible - 1))
        let ages = points.map { min(now - $0.time + liftAging, style.fadeDuration) }
        let widths = ages.map { CGFloat(style.width * (1 - (1 - style.tailWidthScale) * $0 / style.fadeDuration)) }
        let normals = Self.normals(of: points.map(\.location))
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        for (layers, scale) in [(strokeLayers, 1.0), (glowLayers, style.glowWidthScale)] {
            for (band, layer) in layers.enumerated() {
                let newest = style.fadeDuration * Double(band) / Double(layers.count)
                let oldest = style.fadeDuration * Double(band + 1) / Double(layers.count)
                // The band's points, oldest first, and the oldest point of the next newer band,
                // so neighboring bands share an edge.
                var indices = points.indices.filter { ages[$0] >= newest && ages[$0] <= oldest }
                if let joint = points.indices.first(where: { ages[$0] < newest }) {
                    indices.append(joint)
                }
                layer.path = Self.ribbon(
                    through: indices.map { (points[$0].location, normals[$0], widths[$0] * CGFloat(scale) / 2) },
                    roundsNewestEnd: band == 0
                )
            }
        }
        CATransaction.commit()
    }

    private func clearPaths() {
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        (glowLayers + strokeLayers).forEach { $0.path = nil }
        CATransaction.commit()
    }

    /// Each point's unit normal: perpendicular to the path through its neighbors, to its left.
    private static func normals(of locations: [CGPoint]) -> [CGVector] {
        locations.indices.map { index in
            let before = locations[max(index - 1, 0)]
            let after = locations[min(index + 1, locations.count - 1)]
            let dx = after.x - before.x
            let dy = after.y - before.y
            let length = hypot(dx, dy)
            return length > 0 ? CGVector(dx: -dy / length, dy: dx / length) : CGVector(dx: 0, dy: 0)
        }
    }

    /// The filled outline of a ribbon through `samples`, oldest first, each `radius` from its
    /// middle on either side, rounded at the newest sample when `roundsNewestEnd`.
    private static func ribbon(
        through samples: [(location: CGPoint, normal: CGVector, radius: CGFloat)],
        roundsNewestEnd: Bool
    ) -> CGPath? {
        guard samples.count > 1 else { return nil }
        let left = samples.map {
            CGPoint(x: $0.location.x + $0.normal.dx * $0.radius, y: $0.location.y + $0.normal.dy * $0.radius)
        }
        let right = samples.map {
            CGPoint(x: $0.location.x - $0.normal.dx * $0.radius, y: $0.location.y - $0.normal.dy * $0.radius)
        }
        let path = CGMutablePath()
        path.addLines(between: left)
        let newest = samples[samples.count - 1]
        if roundsNewestEnd {
            // Around the front of the finger, from its left edge to its right.
            let start = atan2(newest.normal.dy, newest.normal.dx)
            path.addArc(center: newest.location, radius: newest.radius, startAngle: start, endAngle: start - .pi, clockwise: true)
        }
        for point in right.reversed() {
            path.addLine(to: point)
        }
        path.closeSubpath()
        return path
    }

    private static func opacity(of band: Int, bands: Int) -> Float {
        Float(1 - Double(band) / Double(bands))
    }

    private static func bandLayer() -> CAShapeLayer {
        let layer = CAShapeLayer()
        layer.strokeColor = nil
        return layer
    }
}

/// Refreshes the trail each screen refresh without the display link keeping the view alive.
private final class RefreshTarget {
    private weak var view: KeyboardSwipeTrailView?

    init(_ view: KeyboardSwipeTrailView) {
        self.view = view
    }

    @objc func refresh() {
        view?.render()
    }
}
