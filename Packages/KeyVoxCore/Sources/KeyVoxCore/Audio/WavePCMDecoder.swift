import Foundation

/// Strict little-endian RIFF/WAVE PCM decoding. Compressed and extensible formats
/// require a different decoder; they are never interpreted as ordinary PCM.
enum WavePCMDecoder {
    enum Failure: Error { case malformed, unsupportedFormat, nonFiniteSample }

    struct Audio {
        let samples: [Float]
        let sampleRate: Int
    }

    static func decode(_ data: Data) throws -> Audio {
        let bytes = [UInt8](data)
        func integer(_ offset: Int, _ count: Int) -> UInt32 {
            (0..<count).reduce(0) { $0 | UInt32(bytes[offset + $1]) << ($1 * 8) }
        }
        func tag(_ offset: Int, _ value: [UInt8]) -> Bool {
            Array(bytes[offset..<(offset + value.count)]) == value
        }
        guard bytes.count >= 12,
              tag(0, Array("RIFF".utf8)), tag(8, Array("WAVE".utf8)) else {
            throw Failure.unsupportedFormat
        }
        let end = Int(integer(4, 4)) + 8
        guard end >= 12, end == bytes.count else { throw Failure.malformed }
        var format: Range<Int>?
        var payload: Range<Int>?
        var cursor = 12
        while cursor < end {
            guard end - cursor >= 8 else { throw Failure.malformed }
            let count = Int(integer(cursor + 4, 4))
            let start = cursor + 8
            guard count <= end - start else { throw Failure.malformed }
            let range = start..<(start + count)
            if tag(cursor, Array("fmt ".utf8)) {
                guard format == nil else { throw Failure.malformed }
                format = range
            } else if tag(cursor, Array("data".utf8)) {
                guard payload == nil else { throw Failure.malformed }
                payload = range
            }
            cursor = range.upperBound + (count & 1)
            guard cursor <= end else { throw Failure.malformed }
        }
        guard let format, format.count >= 16, let payload else { throw Failure.malformed }
        let f = format.lowerBound
        let encoding = integer(f, 2)
        let channels = Int(integer(f + 2, 2))
        let sampleRate = Int(integer(f + 4, 4))
        let byteRate = Int(integer(f + 8, 4))
        let alignment = Int(integer(f + 12, 2))
        let bits = Int(integer(f + 14, 2))
        guard (encoding == 1 && [8, 16, 24, 32].contains(bits)) ||
              (encoding == 3 && bits == 32) else { throw Failure.unsupportedFormat }
        let width = bits / 8
        guard channels > 0, sampleRate > 0,
              alignment == channels * width, byteRate == sampleRate * alignment,
              payload.count % alignment == 0 else { throw Failure.malformed }
        var samples = [Float]()
        samples.reserveCapacity(payload.count / alignment)
        for frame in stride(from: payload.lowerBound, to: payload.upperBound, by: alignment) {
            var sum = 0.0
            for channel in 0..<channels {
                let raw = integer(frame + channel * width, width)
                let value: Float
                if encoding == 3 {
                    value = Float(bitPattern: raw)
                } else if bits == 8 {
                    value = Float(Int(raw) - 128) / 128
                } else {
                    // Sign extension also handles the three-byte PCM representation.
                    let signed = Int32(bitPattern: raw << (32 - bits)) >> (32 - bits)
                    value = Float(signed) / Float(UInt64(1) << (bits - 1))
                }
                guard value.isFinite else { throw Failure.nonFiniteSample }
                sum += Double(value)
            }
            // Equal channel weighting is explicit; no speaker-layout interpretation.
            samples.append(Float(sum / Double(channels)))
        }
        return Audio(samples: samples, sampleRate: sampleRate)
    }
}
