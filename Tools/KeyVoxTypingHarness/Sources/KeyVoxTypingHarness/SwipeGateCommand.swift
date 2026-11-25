import CoreGraphics
import Foundation
import KeyVoxPredictiveKeyboard

/// Replays touches through the keyboard's swipe gate (`SwipeGate`):
///
/// - Simulated tapping (`TapStreamSimulator`), at least `--taps` per touch model, where any swipe
///   at all is a failure.
/// - swipe.futo.org swipes of words with at least two different letters, landing at rest and
///   300, 200, 100, and 0 ms after a tap, reporting the share the gate lets through and how long
///   it takes, against the shares the gate's research measured.
enum SwipeGateCommand {
    /// The research's measured share of swipes let through, by time since the last tap (nil at
    /// rest), in percent (`tap-vs-swipe/README.md`, table 3b).
    private static let researchShares: [(since: TimeInterval?, share: Double)] = [
        (nil, 99.8), (0.3, 99.5), (0.2, 99.0), (0.1, 98.1), (0.0, 96.4),
    ]

    static func run(_ options: HarnessCommand.SwipeGateOptions) throws {
        var failed = false
        if let planPath = options.planPath {
            failed = try replayTaps(plan: TypingPlan.load(from: planPath), minimumTaps: options.minimumTaps) || failed
        }
        if let swipesPath = options.swipesPath, let layoutPath = options.layoutPath {
            replaySwipes(try FutoSwipes(path: swipesPath, layoutPath: layoutPath, limit: nil))
        }
        if failed { throw HarnessError.planMismatch("the swipe gate turned taps into swipes") }
    }

    /// Returns whether any tap became a swipe.
    private static func replayTaps(plan: TypingPlan, minimumTaps: Int) throws -> Bool {
        let layout = KeyboardLayoutModel()
        let simulator = TapStreamSimulator(layout: layout, gateParameters: SwipeGate<Int>.standardParameters)
        var failed = false
        print("simulated tapping, \(minimumTaps) taps or more per model, pitch \(String(format: "%.1f", layout.keyPitch.width)) pt")
        for hands in [TapStreamSimulator.Hands.twoThumbs, .indexFinger, .stress] {
            for motion in TapStreamSimulator.Motion.allCases {
                for rate in [60.0, 120.0] {
                    let model = TapStreamSimulator.Model(motion: motion, hands: hands, samplesPerSecond: rate)
                    var generator = SeededRandomGenerator(seed: UInt64(model.name.utf8.reduce(5381) { $0 &* 33 &+ UInt64($1) }))
                    var gate = SwipeGate<Int>()
                    var taps = 0
                    var overlapped = 0
                    var swipes = 0
                    var start: TimeInterval = 1_000
                    while taps < minimumTaps {
                        let touches = simulator.touches(typing: plan, model: model, start: start, generator: &generator)
                        let result = replay(touches, through: &gate, pitch: Double(layout.keyPitch.width))
                        taps += touches.count
                        overlapped += result.overlapped
                        swipes += result.swipes
                        start = (touches.last?.upTime ?? start) + 10
                    }
                    failed = failed || swipes > 0
                    print("  \(model.name.padding(toLength: 28, withPad: " ", startingAt: 0)) taps \(taps)  overlapped \(overlapped)  swipes \(swipes)")
                }
            }
        }
        print(failed ? "FAIL: taps became swipes" : "PASS: no tap became a swipe")
        return failed
    }

    /// Feeds `touches` to `gate` in time order, typing a finger when it lifts or when the next
    /// finger lands, as the keyboard does.
    private static func replay(
        _ touches: [TapStreamSimulator.Touch],
        through gate: inout SwipeGate<Int>,
        pitch: Double
    ) -> (swipes: Int, overlapped: Int) {
        enum Kind: Int { case down = 0, move = 1, up = 2 }
        var events: [(time: TimeInterval, kind: Kind, touch: Int, location: CGPoint)] = []
        for (index, touch) in touches.enumerated() {
            events.append((touch.downTime, .down, index, touch.downLocation))
            events += touch.samples.map { ($0.timestamp, .move, index, $0.location) }
            events.append((touch.upTime, .up, index, .zero))
        }
        events.sort { $0.time != $1.time ? $0.time < $1.time : $0.kind.rawValue > $1.kind.rawValue }
        var down: Set<Int> = []
        var typed: Set<Int> = []
        var swipes = 0
        var overlapped = 0
        for event in events {
            switch event.kind {
            case .down:
                if down.isEmpty == false { overlapped += 1 }
                for other in down where typed.insert(other).inserted {
                    gate.recordTap(at: event.time)
                }
                down.insert(event.touch)
                gate.touchBegan(
                    event.touch, at: event.location, time: event.time, pitch: pitch,
                    isEligible: touches[event.touch].isLetter
                )
            case .move:
                if gate.touchMoved(event.touch, to: event.location, time: event.time) {
                    swipes += 1
                }
            case .up:
                down.remove(event.touch)
                if typed.insert(event.touch).inserted {
                    gate.recordTap(at: event.time)
                }
                gate.touchEnded(event.touch)
            }
        }
        return (swipes, overlapped)
    }

    private static func replaySwipes(_ futo: FutoSwipes) {
        let swipes = futo.swipes.filter { $0.samples.count >= 2 && Set($0.word.lowercased()).count >= 2 }
        print("swipe.futo.org swipes of words with two or more different letters: \(swipes.count)")
        for entry in researchShares {
            var passed = 0
            var triggerTimes: [Double] = []
            for swipe in swipes {
                var gate = SwipeGate<Int>()
                let first = swipe.samples[0]
                if let since = entry.since {
                    gate.recordTap(at: first.timestamp - since)
                }
                gate.touchBegan(0, at: first.location, time: first.timestamp, pitch: Double(swipe.canvas.width) / 10, isEligible: true)
                for sample in swipe.samples.dropFirst() where gate.touchMoved(0, to: sample.location, time: sample.timestamp) {
                    passed += 1
                    triggerTimes.append((sample.timestamp - first.timestamp) * 1_000)
                    break
                }
            }
            triggerTimes.sort()
            let share = Double(passed) / Double(swipes.count) * 100
            let label = entry.since.map { "\(Int($0 * 1_000)) ms after a tap" } ?? "at rest"
            print(String(
                format: "  %@: %.2f%% (research %.1f%%), time to swipe p50 %.0f ms p95 %.0f ms",
                label.padding(toLength: 20, withPad: " ", startingAt: 0), share, entry.share,
                triggerTimes.isEmpty ? 0 : triggerTimes[triggerTimes.count / 2],
                triggerTimes.isEmpty ? 0 : triggerTimes[triggerTimes.count * 95 / 100]
            ))
        }
    }
}
