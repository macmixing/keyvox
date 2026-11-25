import XCTest

/// Screen samples of a swipe through a word's key centers, for `SyntheticTouchPath`: each
/// stroke from one key to the next is minimum-jerk (slowing into every key, as aimed hand
/// movements do), 120 ms plus 45 ms per key pitch, given at 20 Hz.
///
/// At a key it loops at, the finger curls once around the key's center while drifting on the
/// way it came, crossing its own path and going on a tenth of a turn past it, as swipe.futo.org's
/// swipers loop at a doubled letter: a loop 0.3 key pitches out from its middle over 500 ms.
enum SwipeGesturePath {
    /// The Simulator plays a synthesized path at the times it gives only when its points are
    /// this sparse; denser paths arrive all at once. The keyboard still sees the screen's own
    /// samples in between.
    static let samplesPerSecond = 20.0
    private static let strokeBase = 0.12
    private static let strokePerPitch = 0.045
    private static let loopRadius = 0.3
    private static let loopDrift = 0.04
    /// How far past one full loop the finger goes on before leaving the key, in turns, as
    /// swipers' loops go on past where they cross.
    private static let loopOvershoot = 0.1
    private static let loopDuration = 0.5

    /// - Parameter loops: The indices of `keys`' letters whose keys the finger loops around.
    static func samples(
        through keys: String,
        loopingAt loops: Set<Int> = [],
        on map: KeyboardKeyMap
    ) throws -> [(point: CGPoint, offset: TimeInterval)] {
        let centers = try keys.lowercased().map { letter in
            try XCTUnwrap(map.point(for: letter, offset: [0, 0]), "no key for \(letter)")
        }
        let pitch = try XCTUnwrap(map.point(for: "w", offset: [0, 0])).x - (try XCTUnwrap(map.point(for: "q", offset: [0, 0]))).x
        var samples: [(point: CGPoint, offset: TimeInterval)] = []
        var time = 0.0
        var position = centers[0]
        for (index, center) in centers.enumerated() {
            if index > 0 {
                let arrival = loops.contains(index) ? loopPoint(0, around: center, from: centers[index - 1], pitch: pitch) : center
                time = stroke(from: position, to: arrival, pitch: pitch, startingAt: time, into: &samples)
                position = arrival
            } else if loops.contains(index) {
                position = loopPoint(0, around: center, from: CGPoint(x: center.x - 1, y: center.y), pitch: pitch)
                samples.append((position, 0))
            } else {
                samples.append((center, 0))
            }
            if loops.contains(index) {
                let from = index > 0 ? centers[index - 1] : CGPoint(x: center.x - 1, y: center.y)
                let steps = Int((loopDuration * samplesPerSecond).rounded(.up))
                for step in 1...steps {
                    let tau = Double(step) / Double(steps)
                    samples.append((loopPoint(tau, around: center, from: from, pitch: pitch), time + loopDuration * tau))
                }
                time += loopDuration
                position = loopPoint(1, around: center, from: from, pitch: pitch)
            }
        }
        return samples
    }

    /// Appends a minimum-jerk stroke and returns when it ends.
    private static func stroke(
        from: CGPoint,
        to: CGPoint,
        pitch: Double,
        startingAt time: TimeInterval,
        into samples: inout [(point: CGPoint, offset: TimeInterval)]
    ) -> TimeInterval {
        let duration = strokeBase + strokePerPitch * hypot(to.x - from.x, to.y - from.y) / pitch
        let steps = max(1, Int((duration * samplesPerSecond).rounded(.up)))
        for step in 1...steps {
            let tau = Double(step) / Double(steps)
            let progress = 10 * pow(tau, 3) - 15 * pow(tau, 4) + 6 * pow(tau, 5)
            samples.append((
                CGPoint(x: from.x + (to.x - from.x) * progress, y: from.y + (to.y - from.y) * progress),
                time + duration * tau
            ))
        }
        return time + duration
    }

    /// A point `tau` of the way along one loop of a prolate cycloid centered on `center`, drifting
    /// the way from `from` to `center`.
    private static func loopPoint(_ tau: Double, around center: CGPoint, from: CGPoint, pitch: Double) -> CGPoint {
        let length = max(hypot(center.x - from.x, center.y - from.y), 1e-9)
        let along = CGVector(dx: (center.x - from.x) / length, dy: (center.y - from.y) / length)
        let across = CGVector(dx: -along.dy, dy: along.dx)
        let a = loopRadius * pitch
        let k = loopDrift * pitch
        let theta = 2 * Double.pi * (1 + loopOvershoot) * tau
        let u = k * (theta - Double.pi) + a * sin(theta)
        let v = a * (1 - cos(theta)) - a
        return CGPoint(x: center.x + u * along.dx + v * across.dx, y: center.y + u * along.dy + v * across.dy)
    }
}
