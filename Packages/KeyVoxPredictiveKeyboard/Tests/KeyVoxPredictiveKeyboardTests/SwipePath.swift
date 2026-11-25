import Foundation
#if canImport(CoreGraphics)
import CoreGraphics
#endif
@testable import KeyVoxPredictiveKeyboard

/// A humanlike swipe of a word on the English default layout's keys (100-point keys), sampled
/// at 60 Hz: each stroke from one letter's key center to the next follows a minimum-jerk
/// profile, slowing into every key and fastest between keys as aimed hand movements are, taking
/// 100 ms plus 50 ms per key pitch it covers.
enum SwipePath {
    private static let samplesPerSecond = 60.0
    private static let strokeBase = 0.1
    private static let strokePerPitch = 0.05

    static func through(_ word: String) -> [SwipeTouchSample] {
        let keys = KeyCenterMap(geometry: TypingLanguage.english.letterLayout.defaultGeometry)
        let centers = word.lowercased().compactMap { keys.center(of: $0) }
        var strokes: [(from: CGPoint, to: CGPoint, start: Double, duration: Double)] = []
        var time = 0.0
        for (from, to) in zip(centers, centers.dropFirst()) {
            let pitches = hypot(Double(to.x - from.x), Double(to.y - from.y)) / Double(keys.pitch.width)
            let duration = strokeBase + strokePerPitch * pitches
            strokes.append((from, to, time, duration))
            time += duration
        }
        guard strokes.isEmpty == false else {
            return [SwipeTouchSample(location: centers[0], timestamp: 0),
                    SwipeTouchSample(location: centers[0], timestamp: strokeBase)]
        }
        var samples: [SwipeTouchSample] = []
        var sampleTime = 0.0
        var stroke = 0
        while sampleTime <= time {
            while stroke < strokes.count - 1, sampleTime > strokes[stroke].start + strokes[stroke].duration {
                stroke += 1
            }
            let current = strokes[stroke]
            let tau = min(max((sampleTime - current.start) / current.duration, 0), 1)
            let progress = 10 * pow(tau, 3) - 15 * pow(tau, 4) + 6 * pow(tau, 5)
            samples.append(SwipeTouchSample(
                location: CGPoint(
                    x: current.from.x + (current.to.x - current.from.x) * progress,
                    y: current.from.y + (current.to.y - current.from.y) * progress
                ),
                timestamp: sampleTime
            ))
            sampleTime += 1 / samplesPerSecond
        }
        samples.append(SwipeTouchSample(location: centers[centers.count - 1], timestamp: time))
        return samples
    }
}
