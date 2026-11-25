import KeyVoxKeyboardThemes
import KeyVoxPredictiveKeyboard
import QuartzCore
import UIKit

/// The trail a swipe leaves across the letter keys, drawn as the keyboard's theme draws it
/// (`KeyboardThemeSwipeTrail`): a stroke with a round head and a head dot at the finger, tapering
/// to a point and fading along the theme's tail of time behind it over nested glow layers, that
/// retracts into its head while the dot blooms once the finger lifts.
///
/// The path runs through the finger's samples as a centripetal Catmull-Rom curve. The stroke and
/// each glow layer are ribbons whose width follows each point's age, cut by age into a fixed set
/// of shape layers whose opacities step finely down the tail; neighboring bands share their edge
/// exactly, so each ribbon reads as one smooth gradient. Each screen refresh while a trail shows
/// only replaces the layers' paths and the head dot's position, with implicit animations off; the
/// bloom is a Core Animation animation. Layers are made only when a theme's glow layer count
/// changes, never per frame.
final class KeyboardSwipeTrailView: UIView {
    private struct Point {
        let location: CGPoint
        let time: TimeInterval
    }

    /// The style resolved for the traits the swipe started with.
    private struct Style {
        let trail: KeyboardThemeSwipeTrail
        let width: CGFloat
    }

    /// How many age bands the stroke and each glow layer are drawn in.
    private static let strokeBands = 32
    private static let glowBands = 8
    /// Samples closer than this to the last kept one add nothing to the drawn path, in points.
    private static let minimumSpacing: CGFloat = 1
    /// The curve is drawn through a point about this often between samples, in points.
    private static let curveStep: CGFloat = 2
    private static let maximumCurveSteps = 8

    private var glowLayers: [[CAShapeLayer]] = []
    private let strokeLayers: [CAShapeLayer]
    private let headLayer = CAShapeLayer()
    private var points: [Point] = []
    private var displayLink: CADisplayLink?
    private var liftTime: TimeInterval?
    private var style: Style?

    override init(frame: CGRect) {
        strokeLayers = (0..<Self.strokeBands).map { _ in Self.bandLayer() }
        super.init(frame: frame)
        isUserInteractionEnabled = false
        backgroundColor = .clear
        strokeLayers.forEach(layer.addSublayer)
        layer.addSublayer(headLayer)
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
        let trail = traitCollection.keyboardThemePalette.swipeTrail
        let isDark = traitCollection.userInterfaceStyle == .dark
        let style = Style(trail: trail, width: CGFloat(isDark ? trail.width.dark : trail.width.light))
        self.style = style
        let color = trail.color.resolvedColor(with: traitCollection).cgColor
        let glow = trail.glowColor.resolvedColor(with: traitCollection).cgColor
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        makeGlowLayers(count: trail.glows.count)
        for (band, layer) in strokeLayers.enumerated() {
            layer.fillColor = color
            layer.opacity = Self.opacity(of: band, bands: Self.strokeBands, exponent: trail.opacityFalloffExponent)
        }
        for (glowLayer, layers) in zip(trail.glows, glowLayers) {
            let glowOpacity = Float(isDark ? glowLayer.opacity.dark : glowLayer.opacity.light)
            for (band, layer) in layers.enumerated() {
                layer.fillColor = glow
                layer.opacity = glowOpacity * Self.opacity(of: band, bands: Self.glowBands, exponent: trail.opacityFalloffExponent)
            }
        }
        let radius = style.width * CGFloat(trail.headScale) / 2
        headLayer.removeAllAnimations()
        headLayer.fillColor = trail.headColor.resolvedColor(with: traitCollection).cgColor
        headLayer.path = CGPath(ellipseIn: CGRect(x: -radius, y: -radius, width: 2 * radius, height: 2 * radius), transform: nil)
        headLayer.transform = CATransform3DIdentity
        headLayer.opacity = 1
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

    /// The finger lifted: the tail retracts into the head while the head dot blooms and fades.
    func lift() {
        guard let style, liftTime == nil else { return }
        liftTime = ProcessInfo.processInfo.systemUptime
        let bloom = CABasicAnimation(keyPath: "transform.scale")
        bloom.fromValue = 1
        bloom.toValue = style.trail.bloomScale
        bloom.duration = style.trail.bloomDuration
        bloom.timingFunction = CAMediaTimingFunction(name: .easeOut)
        bloom.fillMode = .forwards
        bloom.isRemovedOnCompletion = false
        let fade = CABasicAnimation(keyPath: "opacity")
        fade.fromValue = 1
        fade.toValue = 0
        fade.duration = style.trail.liftDuration
        fade.timingFunction = CAMediaTimingFunction(name: .easeOut)
        fade.fillMode = .forwards
        fade.isRemovedOnCompletion = false
        headLayer.add(bloom, forKey: "bloom")
        headLayer.add(fade, forKey: "fade")
    }

    /// Removes the trail at once.
    func cancel() {
        stopRefreshing()
        points = []
        liftTime = nil
        style = nil
        clearPaths()
    }

    /// Keeps one set of band layers per glow layer, under the stroke, outermost lowest.
    private func makeGlowLayers(count: Int) {
        guard glowLayers.count != count else { return }
        glowLayers.joined().forEach { $0.removeFromSuperlayer() }
        glowLayers = (0..<count).map { _ in (0..<Self.glowBands).map { _ in Self.bandLayer() } }
        for layers in glowLayers {
            for band in layers {
                layer.insertSublayer(band, at: 0)
            }
        }
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
        let trail = style.trail
        let now = ProcessInfo.processInfo.systemUptime
        // While the finger is down the tail is the last `tailDuration` of the path; once it lifts
        // the path stops aging and the tail retracts into the head, easing out.
        let reference = liftTime ?? now
        var span = trail.tailDuration
        if let liftTime {
            let progress = min((now - liftTime) / trail.liftDuration, 1)
            guard progress < 1 else { return cancel() }
            span *= pow(1 - progress, 3)
        }
        if let firstKept = points.firstIndex(where: { reference - $0.time <= trail.tailDuration }), firstKept > 2 {
            points.removeFirst(firstKept - 2)
        }
        let curve = Self.curve(through: points)
        guard let head = curve.last else { return clearPaths() }
        // The curve's points within the span, newest last, with the span's end cut exactly.
        var visible: [Point] = []
        for (index, point) in curve.enumerated() where reference - point.time <= span {
            if visible.isEmpty, index > 0 {
                let older = curve[index - 1]
                let fraction = (reference - span - older.time) / max(point.time - older.time, 1e-6)
                visible.append(Point(
                    location: CGPoint(
                        x: older.location.x + (point.location.x - older.location.x) * fraction,
                        y: older.location.y + (point.location.y - older.location.y) * fraction
                    ),
                    time: reference - span
                ))
            }
            visible.append(point)
        }
        let shares = visible.map { min(max((reference - $0.time) / trail.tailDuration, 0), 1) }
        let widths = shares.map { style.width * CGFloat(1 - (1 - trail.tailWidthScale) * $0) }
        let normals = Self.normals(of: visible.map(\.location))
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        Self.draw(strokeLayers, shares: shares, visible: visible, normals: normals, radii: widths.map { $0 / 2 })
        for (glowLayer, layers) in zip(trail.glows, glowLayers) {
            let scale = CGFloat(glowLayer.widthScale)
            Self.draw(layers, shares: shares, visible: visible, normals: normals, radii: widths.map { $0 * scale / 2 })
        }
        headLayer.position = head.location
        CATransaction.commit()
    }

    /// Cuts the ribbon through `visible` into `layers` by share of the tail, each layer's band
    /// sharing its edge with the next.
    private static func draw(
        _ layers: [CAShapeLayer],
        shares: [Double],
        visible: [Point],
        normals: [CGVector],
        radii: [CGFloat]
    ) {
        for (band, layer) in layers.enumerated() {
            let nearest = Double(band) / Double(layers.count)
            let farthest = Double(band + 1) / Double(layers.count)
            var indices = visible.indices.filter { shares[$0] >= nearest && shares[$0] <= farthest }
            if let joint = visible.indices.first(where: { shares[$0] < nearest }) {
                indices.append(joint)
            }
            layer.path = ribbon(
                through: indices.map { (visible[$0].location, normals[$0], radii[$0]) },
                roundsNewestEnd: band == 0
            )
        }
    }

    private func clearPaths() {
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        (glowLayers.joined() + strokeLayers).forEach { $0.path = nil }
        headLayer.removeAllAnimations()
        headLayer.opacity = 0
        CATransaction.commit()
    }

    /// The path through `points` as a centripetal Catmull-Rom curve, which bends through every
    /// sample without overshooting or looping at uneven spacing, with times along it.
    private static func curve(through points: [Point]) -> [Point] {
        guard points.count > 2 else { return points }
        var curve: [Point] = [points[0]]
        for index in 0..<(points.count - 1) {
            let p0 = points[max(index - 1, 0)].location
            let p1 = points[index].location
            let p2 = points[index + 1].location
            let p3 = points[min(index + 2, points.count - 1)].location
            let length = hypot(p2.x - p1.x, p2.y - p1.y)
            let steps = min(max(Int((length / curveStep).rounded(.up)), 1), maximumCurveSteps)
            for step in 1...steps {
                let fraction = Double(step) / Double(steps)
                curve.append(Point(
                    location: step == steps ? p2 : centripetal(p0, p1, p2, p3, at: fraction),
                    time: points[index].time + (points[index + 1].time - points[index].time) * fraction
                ))
            }
        }
        return curve
    }

    /// The point a share `fraction` of the way from `p1` to `p2` on the centripetal Catmull-Rom
    /// curve through `p0` to `p3`.
    private static func centripetal(_ p0: CGPoint, _ p1: CGPoint, _ p2: CGPoint, _ p3: CGPoint, at fraction: Double) -> CGPoint {
        func knot(_ a: CGPoint, _ b: CGPoint) -> Double {
            max(pow(Double(hypot(b.x - a.x, b.y - a.y)), 0.5), 1e-4)
        }
        let t0 = 0.0
        let t1 = t0 + knot(p0, p1)
        let t2 = t1 + knot(p1, p2)
        let t3 = t2 + knot(p2, p3)
        let t = t1 + (t2 - t1) * fraction
        func mix(_ a: CGPoint, _ b: CGPoint, _ ta: Double, _ tb: Double) -> CGPoint {
            let wa = (tb - t) / (tb - ta)
            let wb = (t - ta) / (tb - ta)
            return CGPoint(x: Double(a.x) * wa + Double(b.x) * wb, y: Double(a.y) * wa + Double(b.y) * wb)
        }
        let a1 = mix(p0, p1, t0, t1)
        let a2 = mix(p1, p2, t1, t2)
        let a3 = mix(p2, p3, t2, t3)
        let b1 = mix(a1, a2, t0, t2)
        let b2 = mix(a2, a3, t1, t3)
        return mix(b1, b2, t1, t2)
    }

    /// Each point's unit normal: perpendicular to the path through its neighbors, to its left;
    /// a point with no direction of its own takes its neighbor's.
    private static func normals(of locations: [CGPoint]) -> [CGVector] {
        var normals = locations.indices.map { index -> CGVector? in
            let before = locations[max(index - 1, 0)]
            let after = locations[min(index + 1, locations.count - 1)]
            let dx = after.x - before.x
            let dy = after.y - before.y
            let length = hypot(dx, dy)
            return length > 0 ? CGVector(dx: -dy / length, dy: dx / length) : nil
        }
        for index in normals.indices.reversed() where normals[index] == nil && index + 1 < normals.count {
            normals[index] = normals[index + 1]
        }
        for index in normals.indices where normals[index] == nil && index > 0 {
            normals[index] = normals[index - 1]
        }
        return normals.map { $0 ?? CGVector(dx: 0, dy: 0) }
    }

    /// The filled outline of a ribbon through `samples`, oldest first, each `radius` from its
    /// middle on either side, rounded at the newest sample when `roundsNewestEnd`.
    private static func ribbon(
        through samples: [(location: CGPoint, normal: CGVector, radius: CGFloat)],
        roundsNewestEnd: Bool
    ) -> CGPath? {
        guard samples.count > 1 else { return nil }
        let path = CGMutablePath()
        path.addLines(between: samples.map {
            CGPoint(x: $0.location.x + $0.normal.dx * $0.radius, y: $0.location.y + $0.normal.dy * $0.radius)
        })
        let newest = samples[samples.count - 1]
        if roundsNewestEnd {
            // Around the front of the finger, from its left edge to its right.
            let start = atan2(newest.normal.dy, newest.normal.dx)
            path.addArc(center: newest.location, radius: newest.radius, startAngle: start, endAngle: start - .pi, clockwise: true)
        }
        for sample in samples.reversed() {
            path.addLine(to: CGPoint(x: sample.location.x - sample.normal.dx * sample.radius, y: sample.location.y - sample.normal.dy * sample.radius))
        }
        path.closeSubpath()
        return path
    }

    private static func opacity(of band: Int, bands: Int, exponent: Double) -> Float {
        Float(1 - pow((Double(band) + 0.5) / Double(bands), exponent))
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
