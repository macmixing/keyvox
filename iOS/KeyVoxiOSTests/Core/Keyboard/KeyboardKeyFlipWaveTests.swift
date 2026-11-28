import CoreGraphics
import Testing
@testable import KeyVox_iOS

/// The key flip's wave reaches keys in the order it crosses them, the other way round when it goes
/// the other way, lower rows a little after the rows above, and every key lies flat by its end.
struct KeyboardKeyFlipWaveTests {
    private let size = CGSize(width: 400, height: 220)

    private func timing(x: CGFloat, y: CGFloat, _ direction: KeyboardKeyFlipWave.Direction) -> KeyboardKeyFlipWave.KeyTiming {
        KeyboardKeyFlipWave.timing(forKeyAt: CGPoint(x: x, y: y), in: size, direction: direction)
    }

    @Test func theWaveReachesKeysInTheOrderItCrossesThem() {
        #expect(timing(x: 20, y: 20, .leftToRight).start < timing(x: 200, y: 20, .leftToRight).start)
        #expect(timing(x: 200, y: 20, .leftToRight).start < timing(x: 380, y: 20, .leftToRight).start)
        #expect(timing(x: 380, y: 20, .rightToLeft).start < timing(x: 20, y: 20, .rightToLeft).start)
        #expect(abs(timing(x: 20, y: 20, .leftToRight).start - timing(x: size.width - 20, y: 20, .rightToLeft).start) < 0.000_001)
    }

    @Test func lowerRowsTurnAfterTheRowsAboveThem() {
        #expect(timing(x: 200, y: 20, .leftToRight).start < timing(x: 200, y: 200, .leftToRight).start)
    }

    @Test func aKeyLeavesThenTheNewOneArrivesInItsPlace() {
        let key = timing(x: 200, y: 110, .leftToRight)
        #expect(key.start < key.turnover)
        #expect(key.turnover < key.end)
    }

    @Test func everyKeyLiesFlatByTheEndOfTheWave() {
        for direction in [KeyboardKeyFlipWave.Direction.leftToRight, .rightToLeft] {
            for corner in [CGPoint.zero, CGPoint(x: size.width, y: 0), CGPoint(x: 0, y: size.height), CGPoint(x: size.width, y: size.height)] {
                let key = KeyboardKeyFlipWave.timing(forKeyAt: corner, in: size, direction: direction)
                #expect(key.start >= 0)
                #expect(key.end <= KeyboardKeyFlipWave.duration + 0.000_001)
            }
        }
        #expect(KeyboardKeyFlipWave.timing(forKeyAt: CGPoint(x: -50, y: 500), in: size, direction: .leftToRight).end <= KeyboardKeyFlipWave.duration + 0.000_001)
    }
}
