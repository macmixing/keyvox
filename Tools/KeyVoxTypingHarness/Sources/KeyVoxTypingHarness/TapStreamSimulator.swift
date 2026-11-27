import CoreGraphics
import Foundation
import KeyVoxPredictiveKeyboard

/// Seeded streams of tapping fingers for the swipe gate (`swipe-gate`): every letter of a typing
/// plan, then the space bar, tapped where the plan aims it, held 60 to 200 ms, sampled at the
/// model's rate, with the time between key presses of Jiang et al. ("How We Type", CHI 2020,
/// Table 1) and the finger motion of the model.
struct TapStreamSimulator {
    enum Motion: String, CaseIterable {
        /// The finger slides about 2 points while down (Buschek et al., CHI 2015).
        case natural
        /// The finger starts rolling toward the next key 0 to 100 ms before lifting, at 3 to 12
        /// key pitches a second.
        case roll
        /// The finger drags in a random direction, up to just short of the distance that would
        /// make it a swipe.
        case drag
    }

    enum Hands: String {
        /// Two thumbs; the next press may land before the previous finger lifts.
        case twoThumbs
        /// One index finger; presses never overlap.
        case indexFinger
        /// Two thumbs pressing every 100 to 180 ms.
        case stress
    }

    struct Model {
        let motion: Motion
        let hands: Hands
        let samplesPerSecond: Double

        var name: String { "\(hands.rawValue)/\(motion.rawValue)/\(Int(samplesPerSecond))Hz" }
    }

    /// One finger: where and when it landed, every sample while down, and when it lifted.
    struct Touch {
        let isLetter: Bool
        let downTime: TimeInterval
        let downLocation: CGPoint
        var samples: [SwipeTouchSample]
        let upTime: TimeInterval
    }

    private static let naturalSlide = 2.0
    private static let rollLead = 0.0...0.1
    private static let rollSpeed = 3.0...12.0
    private static let contact = 0.06...0.2
    private static let overlap = 0.0...0.1
    private static let overlapShare = 0.0...0.7
    private static let dragReach = 0.99
    /// Jiang et al. Table 1, two thumbs: mean and SD of the interval, in seconds.
    private static let sameThumb = (0.2894, 0.0636)
    private static let alternatingThumbs = (0.2431, 0.0636)
    private static let sameLetter = (0.1778, 0.0636)
    private static let indexFingerInterval = (0.3809, 0.051)
    private static let stressInterval = 0.1...0.18
    private static let shortestInterval = 0.1

    let layout: KeyboardLayoutModel
    let gateParameters: SwipeGate<Int>.Parameters

    /// The touches of `plan`'s sentences typed with `model`, after `start`.
    func touches(
        typing plan: TypingPlan,
        model: Model,
        start: TimeInterval,
        generator: inout SeededRandomGenerator
    ) -> [Touch] {
        let presses = Self.presses(in: plan)
        let overlapShare = model.hands == .indexFinger ? 0 : Double.random(in: Self.overlapShare, using: &generator)
        var touches: [Touch] = []
        var downTime = start
        var lastCommit: TimeInterval?
        var previous: (letter: Character?, isLeft: Bool, index: Int)?
        var planned: [(press: (letter: Character?, offset: [Double]), down: TimeInterval, contact: TimeInterval)] = []
        for press in presses {
            let isLeft = press.letter.map(Self.isLeftHand) ?? !(previous?.isLeft ?? true)
            if let previous {
                downTime += interval(
                    from: previous.letter, to: press.letter,
                    sameHand: previous.isLeft == isLeft, hands: model.hands, generator: &generator
                )
            }
            planned.append((press, downTime, Double.random(in: Self.contact, using: &generator)))
            previous = (press.letter, isLeft, planned.count - 1)
        }
        for index in planned.indices {
            let current = planned[index]
            var up = current.down + current.contact
            if index + 1 < planned.count {
                let next = planned[index + 1]
                let nextIsLeft = next.press.letter.map(Self.isLeftHand)
                let isLeft = current.press.letter.map(Self.isLeftHand)
                let sameHand = model.hands == .indexFinger || (isLeft != nil && isLeft == nextIsLeft)
                if sameHand {
                    up = min(up, next.down - 0.01)
                } else if Double.random(in: 0..<1, using: &generator) < overlapShare {
                    up = next.down + Double.random(in: Self.overlap, using: &generator)
                }
            }
            let center = current.press.letter.flatMap(layout.center(of:)) ?? spaceCenter
            let pitch = Double(layout.keyPitch.width)
            let landing = CGPoint(
                x: center.x + current.press.offset[0] * pitch,
                y: center.y + current.press.offset[1] * Double(layout.keyPitch.height)
            )
            let since = lastCommit.map { current.down - $0 }
            let nextCenter = index + 1 < planned.count
                ? planned[index + 1].press.letter.flatMap(layout.center(of:)) ?? spaceCenter
                : center
            touches.append(Touch(
                isLetter: current.press.letter != nil,
                downTime: current.down,
                downLocation: landing,
                samples: samples(
                    from: landing, down: current.down, up: up, toward: nextCenter, pitch: pitch,
                    threshold: threshold(since: since), model: model, generator: &generator
                ),
                upTime: up
            ))
            // A finger types when it lifts, or as soon as the next finger lands (rollover).
            lastCommit = index + 1 < planned.count ? min(up, planned[index + 1].down) : up
        }
        return touches
    }

    private var spaceCenter: CGPoint {
        let frame = layout.allKeys.first { $0.key == .space }!.frame
        return CGPoint(x: frame.midX, y: frame.midY)
    }

    /// Each letter of every word with its planned offset in key pitches, and a space after each word.
    private static func presses(in plan: TypingPlan) -> [(letter: Character?, offset: [Double])] {
        plan.sentences.flatMap { sentence in
            zip(sentence.words, sentence.taps).flatMap { word, taps in
                zip(word.filter { $0 != "'" }, taps).map { (Optional($0), $1) } + [(nil, [0, 0])]
            }
        }
    }

    private static func isLeftHand(_ letter: Character) -> Bool {
        "qwertasdfgzxcvb".contains(letter)
    }

    private func interval(
        from previous: Character?,
        to next: Character?,
        sameHand: Bool,
        hands: Hands,
        generator: inout SeededRandomGenerator
    ) -> TimeInterval {
        switch hands {
        case .stress:
            return Double.random(in: Self.stressInterval, using: &generator)
        case .indexFinger:
            return max(Self.shortestInterval, gaussian(Self.indexFingerInterval, generator: &generator))
        case .twoThumbs:
            let distribution = previous != nil && previous == next ? Self.sameLetter
                : sameHand ? Self.sameThumb : Self.alternatingThumbs
            return max(Self.shortestInterval, gaussian(distribution, generator: &generator))
        }
    }

    private func gaussian(_ distribution: (Double, Double), generator: inout SeededRandomGenerator) -> Double {
        let u = Double.random(in: Double.ulpOfOne..<1, using: &generator)
        let v = Double.random(in: 0..<1, using: &generator)
        return distribution.0 + distribution.1 * (-2 * log(u)).squareRoot() * cos(2 * .pi * v)
    }

    /// The distance, in key pitches, the gate asks of a touch landing `since` after the last tap.
    private func threshold(since: TimeInterval?) -> Double {
        guard let since, since < gateParameters.afterTapWindow else { return gateParameters.restingThreshold }
        return gateParameters.restingThreshold + (gateParameters.afterTapThreshold - gateParameters.restingThreshold)
            * (1 - max(since, 0) / gateParameters.afterTapWindow)
    }

    private func samples(
        from landing: CGPoint,
        down: TimeInterval,
        up: TimeInterval,
        toward next: CGPoint,
        pitch: Double,
        threshold: Double,
        model: Model,
        generator: inout SeededRandomGenerator
    ) -> [SwipeTouchSample] {
        let angle = Double.random(in: 0..<(2 * .pi), using: &generator)
        let contact = up - down
        let position: (TimeInterval) -> CGPoint
        switch model.motion {
        case .natural:
            let speed = Self.naturalSlide / contact
            position = { time in
                CGPoint(x: landing.x + cos(angle) * speed * time, y: landing.y + sin(angle) * speed * time)
            }
        case .roll:
            let lead = min(Double.random(in: Self.rollLead, using: &generator), contact)
            let speed = Double.random(in: Self.rollSpeed, using: &generator) * pitch
            let dx = next.x - landing.x
            let dy = next.y - landing.y
            let length = max((dx * dx + dy * dy).squareRoot(), 1)
            position = { time in
                let rolled = max(0, time - (contact - lead)) * speed
                return CGPoint(x: landing.x + dx / length * rolled, y: landing.y + dy / length * rolled)
            }
        case .drag:
            let reach = Double.random(in: 0...Self.dragReach, using: &generator) * threshold * pitch
            position = { time in
                let dragged = reach * time / contact
                return CGPoint(x: landing.x + cos(angle) * dragged, y: landing.y + sin(angle) * dragged)
            }
        }
        let step = 1 / model.samplesPerSecond
        var samples: [SwipeTouchSample] = []
        var time = step
        while time < contact {
            samples.append(SwipeTouchSample(location: position(time), timestamp: down + time))
            time += step
        }
        samples.append(SwipeTouchSample(location: position(contact), timestamp: up))
        return samples
    }
}
