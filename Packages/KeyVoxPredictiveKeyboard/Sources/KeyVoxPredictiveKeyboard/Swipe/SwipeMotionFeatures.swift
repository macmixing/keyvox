/// What the swipe encoder reads at each resampled point: the position, its velocity and
/// acceleration from Savitzky-Golay filters (window 7, quadratic) over the edge-repeated path,
/// the speed, and the turn rate, as `Tools/KeyVoxSwipeModel/model.py` (`swipe_features`) computes
/// them. Derivatives are per resampled point.
enum SwipeMotionFeatures {
    static let count = 8
    private static let firstDerivative: [Float] = [-3.0, -2, -1, 0, 1, 2, 3].map { Float($0 / 28) }
    private static let secondDerivative: [Float] = [5.0, 0, -3, -4, -3, 0, 5].map { Float($0 / 42) }
    private static let turnLimit: Float = 2
    private static let speedFloor: Float = 1e-6

    /// Positions as x, y pairs to the features, feature-major: [count, points].
    static func features(of path: [Float]) -> [Float] {
        let points = path.count / 2
        let reach = firstDerivative.count / 2
        var output = [Float](repeating: 0, count: count * points)
        for point in 0..<points {
            var velocity: (x: Float, y: Float) = (0, 0)
            var acceleration: (x: Float, y: Float) = (0, 0)
            for tap in 0..<firstDerivative.count {
                let source = min(max(point + tap - reach, 0), points - 1)
                let x = path[source * 2]
                let y = path[source * 2 + 1]
                velocity.x += firstDerivative[tap] * x
                velocity.y += firstDerivative[tap] * y
                acceleration.x += secondDerivative[tap] * x
                acceleration.y += secondDerivative[tap] * y
            }
            let speedSquared = velocity.x * velocity.x + velocity.y * velocity.y
            let cross = velocity.x * acceleration.y - velocity.y * acceleration.x
            let values = [
                path[point * 2],
                path[point * 2 + 1],
                velocity.x,
                velocity.y,
                acceleration.x,
                acceleration.y,
                speedSquared.squareRoot(),
                min(max(cross / (speedSquared + speedFloor), -turnLimit), turnLimit),
            ]
            for feature in 0..<count {
                output[feature * points + point] = values[feature]
            }
        }
        return output
    }
}
