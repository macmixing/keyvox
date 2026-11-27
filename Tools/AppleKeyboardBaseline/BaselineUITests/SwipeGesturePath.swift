import XCTest

/// Screen samples of a swipe through a word's key centers, for `SyntheticTouchPath`: each
/// stroke from one key to the next is minimum-jerk (slowing into every key, as aimed hand
/// movements do), 120 ms plus 45 ms per key pitch, given at 20 Hz.
///
/// At a key it loops at, the finger curls once around the key's center while drifting on the
/// way it came, crossing its own path and going on a tenth of a turn past it, as swipe.futo.org's
/// swipers loop at a doubled letter: a loop 0.3 key pitches out from its middle over 500 ms.
enum SwipeGesturePath {
    /// How the finger loops at a key: it rests `pause` seconds where it arrives, then curls
    /// `turns` times round a loop `radius` key pitches out from its middle over `duration` seconds,
    /// drifting `drift` key pitches a turn the way it came. The standard loop is the one described
    /// above; `turns` of 0 is a rest alone.
    struct Loop: Codable {
        var radius = 0.3
        var drift = 0.04
        var duration = 0.5
        var turns = 1.1
        var pause = 0.0
    }

    /// The Simulator plays a synthesized path at the times it gives only when its points are
    /// this sparse; denser paths arrive all at once. The keyboard still sees the screen's own
    /// samples in between.
    static let samplesPerSecond = 20.0
    private static let strokeBase = 0.12
    private static let strokePerPitch = 0.045

    /// - Parameters:
    ///   - loops: The indices of `keys`' letters whose keys the finger loops around.
    ///   - loop: How it loops there.
    static func samples(
        through keys: String,
        loopingAt loops: Set<Int> = [],
        loop: Loop = Loop(),
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
                let arrival = loops.contains(index) ? loopPoint(0, of: loop, around: center, from: centers[index - 1], pitch: pitch) : center
                time = stroke(from: position, to: arrival, pitch: pitch, startingAt: time, into: &samples)
                position = arrival
            } else if loops.contains(index) {
                position = loopPoint(0, of: loop, around: center, from: CGPoint(x: center.x - 1, y: center.y), pitch: pitch)
                samples.append((position, 0))
            } else {
                samples.append((center, 0))
            }
            if loops.contains(index) {
                let from = index > 0 ? centers[index - 1] : CGPoint(x: center.x - 1, y: center.y)
                if loop.pause > 0 {
                    let steps = Int((loop.pause * samplesPerSecond).rounded(.up))
                    for step in 1...steps {
                        samples.append((position, time + loop.pause * Double(step) / Double(steps)))
                    }
                    time += loop.pause
                }
                if loop.turns > 0 {
                    let steps = Int((loop.duration * samplesPerSecond).rounded(.up))
                    for step in 1...steps {
                        let tau = Double(step) / Double(steps)
                        samples.append((loopPoint(tau, of: loop, around: center, from: from, pitch: pitch), time + loop.duration * tau))
                    }
                    time += loop.duration
                    position = loopPoint(1, of: loop, around: center, from: from, pitch: pitch)
                }
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

    /// A point `tau` of the way along `loop`, a prolate cycloid centered on `center`, drifting the
    /// way from `from` to `center`.
    private static func loopPoint(_ tau: Double, of loop: Loop, around center: CGPoint, from: CGPoint, pitch: Double) -> CGPoint {
        let length = max(hypot(center.x - from.x, center.y - from.y), 1e-9)
        let along = CGVector(dx: (center.x - from.x) / length, dy: (center.y - from.y) / length)
        let across = CGVector(dx: -along.dy, dy: along.dx)
        let a = loop.radius * pitch
        let k = loop.drift * pitch
        let theta = 2 * Double.pi * loop.turns * tau
        let u = k * (theta - Double.pi) + a * sin(theta)
        let v = a * (1 - cos(theta)) - a
        return CGPoint(x: center.x + u * along.dx + v * across.dx, y: center.y + u * along.dy + v * across.dy)
    }
}
