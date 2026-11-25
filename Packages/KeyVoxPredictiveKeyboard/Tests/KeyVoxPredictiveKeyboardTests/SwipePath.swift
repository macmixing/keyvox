import Foundation
#if canImport(CoreGraphics)
import CoreGraphics
#endif
@testable import KeyVoxPredictiveKeyboard

/// A humanlike swipe of a word on the English default layout's keys (100-point keys), sampled
/// at 60 Hz: each stroke from one letter's key center to the next follows a minimum-jerk
/// profile, slowing into every key and fastest between keys as aimed hand movements are, taking
/// 100 ms plus 50 ms per key pitch it covers.
///
/// At a key it loops at, the finger curls once around the key's center while drifting on the way
/// it came, crossing its own path and going on a tenth of a turn past it, as swipe.futo.org's
/// swipers loop: a loop 0.3 key pitches out from its middle over 350 ms.
enum SwipePath {
    private static let samplesPerSecond = 60.0
    private static let strokeBase = 0.1
    private static let strokePerPitch = 0.05
    private static let loopRadius = 0.3
    private static let loopDrift = 0.04
    /// How far past one full loop the finger goes on before leaving the key, in turns, as
    /// swipers' loops go on past where they cross.
    private static let loopOvershoot = 0.1
    private static let loopDuration = 0.35

    private struct Segment {
        let start: Double
        let duration: Double
        let position: (Double) -> CGPoint
    }

    /// - Parameters:
    ///   - loops: The indices of the letters of `word` whose keys the finger loops around.
    ///   - circles: How many times it circles each, taking as much longer: 2 is a double circle.
    static func through(_ word: String, loopingAt loops: Set<Int> = [], circles: Double = 1) -> [SwipeTouchSample] {
        let keys = KeyCenterMap(geometry: TypingLanguage.english.letterLayout.defaultGeometry)
        let centers = word.lowercased().compactMap { keys.center(of: $0) }
        let pitch = Double(keys.pitch.width)
        // Each key's way in and way out: its center, or a loop's two ends.
        var ends: [(arrive: CGPoint, leave: CGPoint, loop: ((Double) -> CGPoint)?)] = []
        for (index, center) in centers.enumerated() {
            guard loops.contains(index) else {
                ends.append((center, center, nil))
                continue
            }
            let from = index > 0 ? centers[index - 1] : CGPoint(x: center.x - 1, y: center.y)
            let length = hypot(Double(center.x - from.x), Double(center.y - from.y))
            let along = (x: Double(center.x - from.x) / length, y: Double(center.y - from.y) / length)
            let across = (x: -along.y, y: along.x)
            let a = loopRadius * pitch
            let k = loopDrift * pitch
            // A prolate cycloid: one loop centered on the key, drifting `2πk` along the way in.
            func point(_ tau: Double) -> CGPoint {
                let theta = 2 * Double.pi * (circles + loopOvershoot) * tau
                let u = k * (theta - Double.pi) + a * sin(theta)
                let v = a * (1 - cos(theta)) - a
                return CGPoint(
                    x: Double(center.x) + u * along.x + v * across.x,
                    y: Double(center.y) + u * along.y + v * across.y
                )
            }
            ends.append((point(0), point(1), point))
        }
        var segments: [Segment] = []
        var time = 0.0
        for index in ends.indices {
            if let loop = ends[index].loop {
                segments.append(Segment(start: time, duration: loopDuration * circles, position: loop))
                time += loopDuration * circles
            }
            guard index + 1 < ends.count else { break }
            let from = ends[index].leave
            let to = ends[index + 1].arrive
            let pitches = hypot(Double(to.x - from.x), Double(to.y - from.y)) / pitch
            let duration = strokeBase + strokePerPitch * pitches
            segments.append(Segment(start: time, duration: duration) { tau in
                let progress = 10 * pow(tau, 3) - 15 * pow(tau, 4) + 6 * pow(tau, 5)
                return CGPoint(x: from.x + (to.x - from.x) * progress, y: from.y + (to.y - from.y) * progress)
            })
            time += duration
        }
        guard segments.isEmpty == false else {
            return [SwipeTouchSample(location: centers[0], timestamp: 0),
                    SwipeTouchSample(location: centers[0], timestamp: strokeBase)]
        }
        var samples: [SwipeTouchSample] = []
        var sampleTime = 0.0
        var segment = 0
        while sampleTime <= time {
            while segment < segments.count - 1, sampleTime > segments[segment].start + segments[segment].duration {
                segment += 1
            }
            let current = segments[segment]
            let tau = min(max((sampleTime - current.start) / current.duration, 0), 1)
            samples.append(SwipeTouchSample(location: current.position(tau), timestamp: sampleTime))
            sampleTime += 1 / samplesPerSecond
        }
        samples.append(SwipeTouchSample(location: segments[segments.count - 1].position(1), timestamp: time))
        return samples
    }
}
