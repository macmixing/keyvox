import UIKit

/// Plays the key flip between two sets of keys when the typing language changes
/// (`KeyboardKeyFlipWave`): the leaving keys turn over edge-on as the wave reaches them, and the
/// arriving keys turn in from edge-on where it has passed, or, with Reduce Motion, the two sets
/// crossfade. A key in both sets turns over in place.
///
/// Only the keys' layers are animated, on top of where the keys already are, so the arriving keys
/// take touches from the start, nothing is drawn off screen or kept, and every theme's keys turn
/// as they are drawn.
final class KeyboardKeyFlipTransition {
    private static let animationKey = "KeyboardKeyFlip"
    /// How much a turning key narrows toward its far edge.
    private static let perspective: CGFloat = -1 / 400
    /// How many steps a quarter turn is drawn in.
    private static let stepsPerTurn = 6

    private var animatedLayers: [CALayer] = []
    private var onEnd: (() -> Void)?
    /// Counts the flips started, so a flip that was cut short does not end the one after it.
    private var generation = 0

    /// Turns `outgoing` over into `incoming`, both laid out in `container`, and calls `onEnd` once
    /// the keys have settled or the flip was cut short by `finish()`.
    func run(
        outgoing: [UIView],
        incoming: [UIView],
        in container: UIView,
        direction: KeyboardKeyFlipWave.Direction,
        reduceMotion: Bool,
        onEnd: @escaping () -> Void
    ) {
        finish()
        generation += 1
        let generation = generation
        self.onEnd = onEnd

        let arriving = Set(incoming.map(ObjectIdentifier.init))
        let leaving = Set(outgoing.map(ObjectIdentifier.init))

        CATransaction.begin()
        CATransaction.setCompletionBlock { [weak self] in
            guard let self, self.generation == generation else { return }
            self.end()
        }
        for key in outgoing + incoming.filter({ leaving.contains(ObjectIdentifier($0)) == false }) {
            let leaves = leaving.contains(ObjectIdentifier(key))
            let arrives = arriving.contains(ObjectIdentifier(key))
            let animation: CAAnimation?
            if reduceMotion {
                animation = Self.crossfade(leaves: leaves, arrives: arrives)
            } else {
                let frame = key.convert(key.bounds, to: container)
                animation = Self.flip(
                    timing: KeyboardKeyFlipWave.timing(
                        forKeyAt: CGPoint(x: frame.midX, y: frame.midY),
                        in: container.bounds.size,
                        direction: direction
                    ),
                    leaves: leaves,
                    arrives: arrives
                )
            }
            guard let animation else { continue }
            // A leaving key stays gone until its page is hidden in `onEnd`.
            if arrives == false {
                animation.fillMode = .forwards
                animation.isRemovedOnCompletion = false
            }
            key.layer.add(animation, forKey: Self.animationKey)
            animatedLayers.append(key.layer)
        }
        CATransaction.commit()
    }

    /// Ends a flip under way at once, leaving the arriving keys as they lie.
    func finish() {
        guard onEnd != nil else { return }
        generation += 1
        end()
    }

    private func end() {
        animatedLayers.forEach { $0.removeAnimation(forKey: Self.animationKey) }
        animatedLayers.removeAll()
        let onEnd = onEnd
        self.onEnd = nil
        onEnd?()
    }

    /// A key fading out, in, or, when it stays, not at all.
    private static func crossfade(leaves: Bool, arrives: Bool) -> CAAnimation? {
        guard leaves != arrives else { return nil }
        let fade = CABasicAnimation(keyPath: "opacity")
        fade.fromValue = leaves ? 1 : 0
        fade.toValue = leaves ? 0 : 1
        fade.duration = KeyboardKeyFlipWave.crossfadeDuration
        fade.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
        return fade
    }

    /// A key turning away edge-on from `timing.start`, turning in from edge-on at
    /// `timing.turnover`, or both in turn, shown only while it is the key in its place.
    private static func flip(timing: KeyboardKeyFlipWave.KeyTiming, leaves: Bool, arrives: Bool) -> CAAnimation {
        let duration = KeyboardKeyFlipWave.duration
        let quarterTurn = CGFloat.pi / 2
        var times: [TimeInterval] = [0]
        var angles: [CGFloat] = [leaves ? 0 : -quarterTurn]
        if leaves {
            for step in 0...stepsPerTurn {
                let progress = Double(step) / Double(stepsPerTurn)
                times.append(timing.start + (timing.turnover - timing.start) * progress)
                // Picks up speed as it turns away.
                angles.append(quarterTurn * CGFloat(progress * progress))
            }
        }
        if arrives {
            for step in 0...stepsPerTurn {
                let progress = Double(step) / Double(stepsPerTurn)
                times.append(timing.turnover + (timing.end - timing.turnover) * progress)
                // Slows as it comes to lie flat.
                angles.append(-quarterTurn * CGFloat((1 - progress) * (1 - progress)))
            }
        }
        times.append(duration)
        angles.append(arrives ? 0 : quarterTurn)

        let turn = CAKeyframeAnimation(keyPath: "transform")
        turn.values = angles.map { angle in
            var transform = CATransform3DIdentity
            transform.m34 = perspective
            return NSValue(caTransform3D: CATransform3DRotate(transform, angle, 1, 0, 0))
        }
        turn.keyTimes = times.map { NSNumber(value: min($0 / duration, 1)) }

        let group = CAAnimationGroup()
        group.duration = duration
        group.animations = [turn]
        if leaves != arrives {
            let shown = CAKeyframeAnimation(keyPath: "opacity")
            shown.calculationMode = .discrete
            shown.values = leaves ? [1, 0] : [0, 1]
            shown.keyTimes = [0, NSNumber(value: timing.turnover / duration), 1]
            group.animations?.append(shown)
        }
        group.animations?.forEach { $0.duration = duration }
        return group
    }
}
