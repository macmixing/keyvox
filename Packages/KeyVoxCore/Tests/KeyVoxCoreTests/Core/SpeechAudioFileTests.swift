import Foundation
import XCTest
@testable import KeyVoxCore

final class SpeechAudioFileTests: LinguisticAnalyzerTestCase {
    private func little(_ value: UInt32, count: Int) -> [UInt8] {
        (0..<count).map { UInt8(truncatingIfNeeded: value >> ($0 * 8)) }
    }

    private func chunk(_ tag: String, _ bytes: [UInt8]) -> [UInt8] {
        Array(tag.utf8) + little(UInt32(bytes.count), count: 4) + bytes +
            (bytes.count.isMultiple(of: 2) ? [] : [0])
    }

    private func wave(bits: Int, channels: Int = 1, encoding: Int = 1,
                      payload: [UInt8], dataFirst: Bool = false) -> Data {
        let rate = 16_000
        let alignment = channels * bits / 8
        let format = little(UInt32(encoding), count: 2) + little(UInt32(channels), count: 2) +
            little(UInt32(rate), count: 4) + little(UInt32(rate * alignment), count: 4) +
            little(UInt32(alignment), count: 2) + little(UInt32(bits), count: 2)
        let f = chunk("fmt ", format)
        let d = chunk("data", payload)
        let body = Array("WAVE".utf8) + chunk("JUNK", [0]) + (dataFirst ? d + f : f + d)
        return Data(Array("RIFF".utf8) + little(UInt32(body.count), count: 4) + body)
    }

    func testIntegerWidthsAndChunkOrdering() throws {
        for bits in [8, 16, 24, 32] {
            let minimum: UInt32 = bits == 8 ? 0 : 1 << (bits - 1)
            let zero: UInt32 = bits == 8 ? 128 : 0
            let payload = little(minimum, count: bits / 8) + little(zero, count: bits / 8)
            let result = try WavePCMDecoder.decode(wave(bits: bits, payload: payload, dataFirst: true))
            XCTAssertEqual(result.samples, [-1, 0])
            XCTAssertEqual(result.sampleRate, 16_000)
        }
    }

    func testFloatDownmixAndIdentity() throws {
        let values: [Float] = [0.75, -0.25, -1, 1]
        let payload = values.flatMap { little($0.bitPattern, count: 4) }
        let result = try WavePCMDecoder.decode(wave(bits: 32, channels: 2, encoding: 3, payload: payload))
        XCTAssertEqual(result.samples, [0.25, 0])
        XCTAssertEqual(try PCMResampler.resample(result.samples, from: 16_000, to: 16_000), result.samples)
    }

    func testRejectsTruncationUnsupportedFormatsAndInvalidSamples() {
        let valid = wave(bits: 16, payload: [0, 0, 1, 0])
        for count in 0..<valid.count {
            XCTAssertThrowsError(try WavePCMDecoder.decode(Data(valid.prefix(count))))
        }
        XCTAssertThrowsError(try WavePCMDecoder.decode(wave(bits: 16, payload: [0])))
        XCTAssertThrowsError(try WavePCMDecoder.decode(wave(bits: 16, encoding: 0xfffe, payload: [0, 0])))
        XCTAssertThrowsError(try WavePCMDecoder.decode(wave(bits: 32, encoding: 3,
                                                          payload: little(Float.nan.bitPattern, count: 4))))
        XCTAssertThrowsError(try PCMResampler.resample([.infinity], from: 16_000, to: 16_000))
        XCTAssertThrowsError(try PCMResampler.resample([0], from: 0, to: 16_000))
        XCTAssertThrowsError(try PCMResampler.resample([0], from: 1, to: 16_000))
        XCTAssertThrowsError(try PCMResampler.resample([0], from: Int.max, to: 16_000))
        let extreme = Float.greatestFiniteMagnitude
        XCTAssertThrowsError(try PCMResampler.resample([extreme, extreme, -extreme, -extreme],
                                                       from: 8_000, to: 16_000))
    }

    func testResamplingPreservesDCAndSuppressesAliasing() throws {
        let inputRate = 48_000
        let outputRate = 16_000
        let count = 4_800
        let dc = try PCMResampler.resample(Array(repeating: 0.25, count: count), from: inputRate, to: outputRate)
        XCTAssertEqual(dc.count, 1_600)
        XCTAssertTrue(dc.allSatisfy { abs($0 - 0.25) < 0.00001 })
        func rms(at frequency: Double) throws -> Double {
            let signal = (0..<count).map { Float(sin(2 * .pi * frequency * Double($0) / Double(inputRate))) }
            let converted = try PCMResampler.resample(signal, from: inputRate, to: outputRate)
            let interior = converted.dropFirst(100).dropLast(100)
            return sqrt(interior.reduce(0.0) { $0 + Double($1 * $1) } / Double(interior.count))
        }
        XCTAssertGreaterThan(try rms(at: 1_000), 0.7)
        XCTAssertLessThan(try rms(at: 12_000), 0.001)
        let upsampled = try PCMResampler.resample([0.25, 0.25], from: 8_000, to: 16_000)
        XCTAssertEqual(upsampled, Array(repeating: 0.25, count: 4))
    }
}
