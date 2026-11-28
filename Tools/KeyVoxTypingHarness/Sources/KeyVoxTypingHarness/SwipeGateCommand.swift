import CoreGraphics
import Foundation
import KeyVoxPredictiveKeyboard
import KeyVoxTypingSimulation

/// Replays touches through the keyboard's swipe gate (`SwipeGate`):
///
/// - Simulated tapping (`TapStreamSimulator`), at least `--taps` per touch model, where any swipe
///   at all is a failure.
/// - swipe.futo.org swipes of words with at least two different letters, each alone, landing at
///   rest and 300, 200, 100, and 0 ms after a tap, reporting the share the gate lets through and
///   how long it takes to decide, against the shares the gate's research measured; a share more
///   than `recallTolerance` below the research's is a failure.
/// - With swipe.futo.org's own records, which name each swipe's session, each session's swipes in
///   the order and at the times they were recorded, so a swipe the gate leaves undecided meets the
///   swipe after it as in real swipe typing.
enum SwipeGateCommand {
    /// The research's measured share of swipes let through, by time since the last tap (nil at
    /// rest), in percent (`tap-vs-swipe/README.md`, table 3b).
    private static let researchShares: [(since: TimeInterval?, share: Double)] = [
        (nil, 99.8), (0.3, 99.5), (0.2, 99.0), (0.1, 98.1), (0.0, 96.4),
    ]
    /// How far below a research share, in percentage points, still matches it: the research
    /// reports one decimal.
    private static let recallTolerance = 0.05

    static func run(_ options: HarnessCommand.SwipeGateOptions) throws {
        var failed = false
        if let planPath = options.planPath {
            failed = try replayTaps(plan: TypingPlan.load(from: planPath), minimumTaps: options.minimumTaps) || failed
        }
        if let swipesPath = options.swipesPath, let layoutPath = options.layoutPath {
            let futo = try FutoSwipes(path: swipesPath, layoutPath: layoutPath, limit: nil)
            failed = replaySwipes(futo) || failed
            replaySessions(futo)
        }
        if failed { throw HarnessError.planMismatch("the swipe gate failed a check") }
    }

    /// Returns whether any tap became a swipe.
    private static func replayTaps(plan: TypingPlan, minimumTaps: Int) throws -> Bool {
        // Typing plans type English.
        let layout = KeyboardLayoutModel(language: try TypingLanguage.bundled(identifier: "en"))
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
                    var result = ReplayResult()
                    var start: TimeInterval = 1_000
                    while taps < minimumTaps {
                        let touches = simulator.touches(typing: plan, model: model, start: start, generator: &generator)
                        result.add(replay(touches, through: &gate, pitch: Double(layout.keyPitch.width)))
                        taps += touches.count
                        start = (touches.last?.upTime ?? start) + 10
                    }
                    failed = failed || result.swipes > 0
                    print("  \(model.name.padding(toLength: 28, withPad: " ", startingAt: 0)) taps \(taps)  overlapped \(result.overlapped)"
                          + "  met the threshold \(result.metThreshold)  undecided \(result.undecided)  swipes \(result.swipes)")
                }
            }
        }
        print(failed ? "FAIL: taps became swipes" : "PASS: no tap became a swipe")
        return failed
    }

    private struct ReplayResult {
        var swipes = 0
        var overlapped = 0
        /// Taps the threshold alone would have made swipes.
        var metThreshold = 0
        var undecided = 0

        mutating func add(_ other: ReplayResult) {
            swipes += other.swipes
            overlapped += other.overlapped
            metThreshold += other.metThreshold
            undecided += other.undecided
        }
    }

    /// Feeds `touches` to `gate` in time order, typing a finger when it lifts or when the next
    /// finger lands, as the keyboard does.
    private static func replay(
        _ touches: [TapStreamSimulator.Touch],
        through gate: inout SwipeGate<Int>,
        pitch: Double
    ) -> ReplayResult {
        enum Kind: Int { case down = 0, move = 1, up = 2 }
        var events: [(time: TimeInterval, kind: Kind, touch: Int, location: CGPoint)] = []
        for (index, touch) in touches.enumerated() {
            events.append((touch.downTime, .down, index, touch.downLocation))
            events += touch.samples.map { ($0.timestamp, .move, index, $0.location) }
            events.append((touch.upTime, .up, index, touch.samples.last?.location ?? touch.downLocation))
        }
        events.sort { $0.time != $1.time ? $0.time < $1.time : $0.kind.rawValue > $1.kind.rawValue }
        var down: Set<Int> = []
        var typed: Set<Int> = []
        var swiping: Set<Int> = []
        var result = ReplayResult()
        var thresholdGate = SwipeGate<Int>(parameters: thresholdOnly)
        for event in events {
            result.swipes += gate.settleUndecided(at: event.time).count
            switch event.kind {
            case .down:
                for _ in gate.settleUndecidedAsTaps() {
                    gate.recordTap(at: event.time)
                }
                if down.isEmpty == false { result.overlapped += 1 }
                for other in down where typed.insert(other).inserted {
                    gate.recordTap(at: event.time)
                    thresholdGate.recordTap(at: event.time)
                }
                down.insert(event.touch)
                let isEligible = touches[event.touch].isLetter
                gate.touchBegan(event.touch, at: event.location, time: event.time, pitch: pitch, isEligible: isEligible)
                thresholdGate.touchBegan(event.touch, at: event.location, time: event.time, pitch: pitch, isEligible: isEligible)
            case .move:
                if gate.touchMoved(event.touch, to: event.location, time: event.time), swiping.insert(event.touch).inserted {
                    result.swipes += 1
                }
                if thresholdGate.touchMoved(event.touch, to: event.location, time: event.time) {
                    result.metThreshold += 1
                }
            case .up:
                down.remove(event.touch)
                thresholdGate.touchCancelled(event.touch)
                switch gate.touchEnded(event.touch, at: event.location, time: event.time) {
                case .swipe:
                    if swiping.insert(event.touch).inserted { result.swipes += 1 }
                case .undecided:
                    result.undecided += 1
                    typed.insert(event.touch)
                case .tap:
                    if typed.insert(event.touch).inserted {
                        gate.recordTap(at: event.time)
                        thresholdGate.recordTap(at: event.time)
                    }
                }
            }
        }
        result.swipes += gate.settleUndecided(at: .infinity).count
        return result
    }

    /// The research's threshold alone, without the hold or lift evidence, for counting the taps
    /// that meet it.
    private static var thresholdOnly: SwipeGate<Int>.Parameters {
        var parameters = SwipeGate<Int>.standardParameters
        parameters.holdAfterThreshold = 0
        return parameters
    }

    /// Returns whether a share fell short of the research's.
    private static func replaySwipes(_ futo: FutoSwipes) -> Bool {
        let swipes = futo.swipes.filter { $0.samples.count >= 2 && Set($0.word.lowercased()).count >= 2 }
        print("swipe.futo.org swipes of words with two or more different letters, each alone: \(swipes.count)")
        var failed = false
        for entry in researchShares {
            var decisionTimes: [Double] = []
            var undecided = 0
            for swipe in swipes {
                var gate = SwipeGate<Int>()
                let first = swipe.samples[0]
                if let since = entry.since {
                    gate.recordTap(at: first.timestamp - since)
                }
                gate.touchBegan(0, at: first.location, time: first.timestamp, pitch: Double(swipe.canvas.width) / 10, isEligible: true)
                var decidedAt: TimeInterval?
                for sample in swipe.samples.dropFirst().dropLast() where gate.touchMoved(0, to: sample.location, time: sample.timestamp) {
                    decidedAt = sample.timestamp
                    break
                }
                let last = swipe.samples[swipe.samples.count - 1]
                if decidedAt == nil {
                    switch gate.touchEnded(0, at: last.location, time: last.timestamp) {
                    case .swipe:
                        decidedAt = last.timestamp
                    case .undecided:
                        undecided += 1
                        decidedAt = gate.settleUndecided(at: .infinity).isEmpty ? nil : last.timestamp + gate.parameters.undecidedWindow
                    case .tap:
                        break
                    }
                }
                if let decidedAt {
                    decisionTimes.append((decidedAt - first.timestamp) * 1_000)
                }
            }
            decisionTimes.sort()
            let share = Double(decisionTimes.count) / Double(swipes.count) * 100
            failed = failed || share < entry.share - recallTolerance
            let label = entry.since.map { "\(Int($0 * 1_000)) ms after a tap" } ?? "at rest"
            print(String(
                format: "  %@: %.2f%% (research %.1f%%), undecided at lift %d, time to decide p50 %.0f ms p95 %.0f ms",
                label.padding(toLength: 20, withPad: " ", startingAt: 0), share, entry.share, undecided,
                decisionTimes.isEmpty ? 0 : decisionTimes[decisionTimes.count / 2],
                decisionTimes.isEmpty ? 0 : decisionTimes[decisionTimes.count * 95 / 100]
            ))
        }
        print(failed ? "FAIL: the gate lets through fewer swipes than the research measured" : "PASS: the gate lets through the swipes the research measured")
        return failed
    }

    /// Each session's swipes in order, at their recorded times, through one gate.
    private static func replaySessions(_ futo: FutoSwipes) {
        let sessions = Dictionary(grouping: futo.swipes.filter { $0.session != nil && $0.number != nil && $0.samples.count >= 2 }) { $0.session! }
        guard sessions.isEmpty == false else { return }
        var total = 0
        var swiped = 0
        var undecided = 0
        var settledAsTaps = 0
        for swipes in sessions.values {
            var gate = SwipeGate<Int>()
            var outcome: [Int: Bool] = [:]
            for swipe in swipes.sorted(by: { $0.number! < $1.number! }) {
                let id = swipe.number!
                let first = swipe.samples[0]
                for settled in gate.settleUndecided(at: first.timestamp) { outcome[settled] = true }
                for settled in gate.settleUndecidedAsTaps() {
                    outcome[settled] = false
                    settledAsTaps += 1
                }
                gate.touchBegan(id, at: first.location, time: first.timestamp, pitch: Double(swipe.canvas.width) / 10, isEligible: true)
                var isSwipe = false
                for sample in swipe.samples.dropFirst().dropLast() where gate.touchMoved(id, to: sample.location, time: sample.timestamp) {
                    isSwipe = true
                    break
                }
                let last = swipe.samples[swipe.samples.count - 1]
                switch gate.touchEnded(id, at: last.location, time: last.timestamp) {
                case .swipe: isSwipe = true
                case .undecided: undecided += 1
                case .tap: break
                }
                if Set(swipe.word.lowercased()).count >= 2 {
                    total += 1
                    outcome[id] = isSwipe ? true : outcome[id]
                }
            }
            for settled in gate.settleUndecided(at: .infinity) { outcome[settled] = true }
            swiped += swipes.filter { Set($0.word.lowercased()).count >= 2 && outcome[$0.number!] == true }.count
        }
        print(String(
            format: "swipe.futo.org sessions replayed in order: %d swipes, %.3f%% let through, %d undecided at lift, %d of them typed as taps because the next swipe followed within %.0f ms",
            total, Double(swiped) / Double(total) * 100, undecided, settledAsTaps, SwipeGate<Int>.standardParameters.undecidedWindow * 1_000
        ))
    }
}
