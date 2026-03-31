import Foundation

enum ParakeetFloat16Storage {
    private static let signMask: UInt16 = 0x8000
    private static let exponentMask: UInt16 = 0x7C00
    private static let significandMask: UInt16 = 0x03FF
    private static let float32InfinityExponent: UInt32 = 0x7F80_0000
    private static let float32SignificandRoundingMask: UInt32 = 0x0000_1FFF
    private static let float32SignificandHalfwayMask: UInt32 = 0x0000_1000
    private static let float32NormalizedHiddenBit: UInt32 = 0x0080_0000
    private static let float16NormalizedHiddenBit: UInt16 = 0x0400

    static func bitPattern(from value: Float) -> UInt16 {
        let bits = value.bitPattern
        let sign = UInt16((bits >> 16) & UInt32(signMask))
        let exponent = Int((bits >> 23) & 0xFF)
        let significand = bits & 0x007F_FFFF

        if exponent == 0xFF {
            if significand == 0 {
                return sign | exponentMask
            }
            return sign | exponentMask | 0x0200
        }

        if exponent == 0 {
            return sign
        }

        let adjustedExponent = exponent - 127 + 15
        if adjustedExponent >= 0x1F {
            return sign | exponentMask
        }

        if adjustedExponent <= 0 {
            if adjustedExponent < -10 {
                return sign
            }

            let normalizedSignificand = significand | float32NormalizedHiddenBit
            let shift = UInt32(14 - adjustedExponent)
            var halfSignificand = UInt16(normalizedSignificand >> shift)
            let remainderMask = (UInt32(1) << shift) - 1
            let remainder = normalizedSignificand & remainderMask
            let halfway = UInt32(1) << (shift - 1)

            if remainder > halfway || (remainder == halfway && (halfSignificand & 1) == 1) {
                halfSignificand &+= 1
            }

            if (halfSignificand & float16NormalizedHiddenBit) != 0 {
                return sign | float16NormalizedHiddenBit
            }

            return sign | halfSignificand
        }

        var halfExponent = UInt16(adjustedExponent) << 10
        var halfSignificand = UInt16(significand >> 13)
        let remainder = significand & float32SignificandRoundingMask

        if remainder > float32SignificandHalfwayMask || (
            remainder == float32SignificandHalfwayMask && (halfSignificand & 1) == 1
        ) {
            halfSignificand &+= 1
            if (halfSignificand & float16NormalizedHiddenBit) != 0 {
                halfSignificand = 0
                halfExponent &+= float16NormalizedHiddenBit
                if halfExponent >= exponentMask {
                    return sign | exponentMask
                }
            }
        }

        return sign | halfExponent | halfSignificand
    }

    static func float(from bitPattern: UInt16) -> Float {
        let sign = UInt32(bitPattern & signMask) << 16
        let exponent = Int((bitPattern & exponentMask) >> 10)
        let significand = UInt32(bitPattern & significandMask)

        let floatBits: UInt32

        switch exponent {
        case 0:
            if significand == 0 {
                floatBits = sign
            } else {
                var normalizedSignificand = significand
                var adjustedExponent = -14

                while (normalizedSignificand & UInt32(float16NormalizedHiddenBit)) == 0 {
                    normalizedSignificand <<= 1
                    adjustedExponent -= 1
                }

                normalizedSignificand &= UInt32(significandMask)
                let exponentBits = UInt32(adjustedExponent + 127) << 23
                floatBits = sign | exponentBits | (normalizedSignificand << 13)
            }
        case 0x1F:
            floatBits = sign | float32InfinityExponent | (significand << 13)
        default:
            let exponentBits = UInt32(exponent - 15 + 127) << 23
            floatBits = sign | exponentBits | (significand << 13)
        }

        return Float(bitPattern: floatBits)
    }
}
