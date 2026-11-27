import Foundation
// Android's C library supplies the `Float` math functions Foundation brings in elsewhere.
#if canImport(Android)
import Android
#endif
#if canImport(Accelerate)
import Accelerate
#endif

/// The numeric kernels swipe inference runs on: Accelerate where the platform has it, and the
/// same arithmetic in plain Swift elsewhere, such as Android.
enum SwipeMath {
    /// `C = A' * B' + beta * C` for row-major matrices, where `A'` is `A` ([m, k]) or, transposed,
    /// `A` stored as [k, m], and likewise `B'` is [k, n] or stored as [n, k].
    static func multiply(
        _ a: UnsafePointer<Float>, transposingA: Bool = false,
        _ b: UnsafePointer<Float>, transposingB: Bool = false,
        into c: UnsafeMutablePointer<Float>,
        m: Int, n: Int, k: Int,
        accumulating: Bool = false
    ) {
        #if canImport(Accelerate)
        cblas_sgemm(
            CblasRowMajor,
            transposingA ? CblasTrans : CblasNoTrans,
            transposingB ? CblasTrans : CblasNoTrans,
            __LAPACK_int(m), __LAPACK_int(n), __LAPACK_int(k),
            1,
            a, __LAPACK_int(transposingA ? m : k),
            b, __LAPACK_int(transposingB ? k : n),
            accumulating ? 1 : 0,
            c, __LAPACK_int(n)
        )
        #else
        multiplyPortably(a, transposingA: transposingA, b, transposingB: transposingB, into: c, m: m, n: n, k: k, accumulating: accumulating)
        #endif
    }

    /// `multiply` in plain Swift, for platforms without Accelerate.
    static func multiplyPortably(
        _ a: UnsafePointer<Float>, transposingA: Bool = false,
        _ b: UnsafePointer<Float>, transposingB: Bool = false,
        into c: UnsafeMutablePointer<Float>,
        m: Int, n: Int, k: Int,
        accumulating: Bool = false
    ) {
        if accumulating == false {
            c.update(repeating: 0, count: m * n)
        }
        for row in 0..<m {
            let output = c + row * n
            for inner in 0..<k {
                let scale = transposingA ? a[inner * m + row] : a[row * k + inner]
                guard scale != 0 else { continue }
                if transposingB {
                    for column in 0..<n { output[column] += scale * b[column * k + inner] }
                } else {
                    let input = b + inner * n
                    for column in 0..<n { output[column] += scale * input[column] }
                }
            }
        }
    }

    /// Writes `count` little-endian fp16 values starting at `source`, which need not be aligned,
    /// to `destination` as `Float`.
    static func widenHalfPrecision(_ source: UnsafeRawPointer, count: Int, into destination: UnsafeMutablePointer<Float>) {
        for index in 0..<count {
            let bits = UInt16(littleEndian: source.loadUnaligned(fromByteOffset: index * 2, as: UInt16.self))
            #if arch(arm64)
            destination[index] = Float(Float16(bitPattern: bits))
            #else
            destination[index] = widened(bits)
            #endif
        }
    }

    /// An fp16 bit pattern as `Float`, for processors without a native half-precision type.
    static func widened(_ bits: UInt16) -> Float {
        let sign = UInt32(bits & 0x8000) << 16
        var exponent = Int32(bits >> 10) & 0x1F
        var mantissa = UInt32(bits) & 0x3FF
        if exponent == 0x1F {
            return Float(bitPattern: sign | 0x7F80_0000 | mantissa << 13)
        }
        if exponent == 0 {
            guard mantissa != 0 else { return Float(bitPattern: sign) }
            // A subnormal half is a normal float: shift its mantissa up to the implicit bit.
            exponent = 1
            while mantissa & 0x400 == 0 {
                mantissa <<= 1
                exponent -= 1
            }
            mantissa &= 0x3FF
        }
        return Float(bitPattern: sign | UInt32(exponent + 112) << 23 | mantissa << 13)
    }

    static func sigmoid(_ x: Float) -> Float {
        1 / (1 + exp(-x))
    }

    /// `log(sigmoid(x))`, without overflow for large `|x|`.
    static func logSigmoid(_ x: Float) -> Float {
        -logAddExp(0, -x)
    }

    static func logAddExp(_ a: Float, _ b: Float) -> Float {
        let high = max(a, b)
        return high + log1p(exp(-abs(a - b)))
    }

    static func hardSwish(_ x: Float) -> Float {
        x * min(max(x + 3, 0), 6) / 6
    }

    /// Replaces `count` values with their log-softmax.
    static func logSoftmax(_ values: UnsafeMutablePointer<Float>, count: Int) {
        var high = -Float.infinity
        for index in 0..<count { high = max(high, values[index]) }
        var total: Float = 0
        for index in 0..<count {
            values[index] -= high
            total += exp(values[index])
        }
        let logTotal = log(total)
        for index in 0..<count { values[index] -= logTotal }
    }
}
