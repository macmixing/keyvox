import XCTest
@testable import KeyVoxPredictiveKeyboard

/// The plain-Swift kernels swipe inference runs on where Accelerate and a native half-precision
/// type are missing, such as Android, compute what Accelerate and `Float16` do.
final class SwipeMathTests: XCTestCase {
    func testThePortableMatrixProductMatchesAccelerate() {
        var generator = SystemRandomNumberGenerator()
        let (m, n, k) = (7, 5, 11)
        for transposingA in [false, true] {
            for transposingB in [false, true] {
                for accumulating in [false, true] {
                    let a = (0..<(m * k)).map { _ in Float.random(in: -2...2, using: &generator) }
                    let b = (0..<(k * n)).map { _ in Float.random(in: -2...2, using: &generator) }
                    let start = (0..<(m * n)).map { _ in Float.random(in: -2...2, using: &generator) }
                    var expected = start
                    var portable = start
                    SwipeMath.multiply(a, transposingA: transposingA, b, transposingB: transposingB,
                                       into: &expected, m: m, n: n, k: k, accumulating: accumulating)
                    SwipeMath.multiplyPortably(a, transposingA: transposingA, b, transposingB: transposingB,
                                               into: &portable, m: m, n: n, k: k, accumulating: accumulating)
                    for (left, right) in zip(expected, portable) {
                        XCTAssertEqual(left, right, accuracy: 1e-4)
                    }
                }
            }
        }
    }

    func testThePortableHalfPrecisionWideningMatchesFloat16ForEveryValue() {
        for bits in UInt16.min...UInt16.max {
            let native = Float(Float16(bitPattern: bits))
            let portable = SwipeMath.widened(bits)
            if native.isNaN {
                XCTAssertTrue(portable.isNaN, "\(bits)")
            } else {
                XCTAssertEqual(native.bitPattern, portable.bitPattern, "\(bits)")
            }
        }
    }
}
