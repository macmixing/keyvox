import Foundation

enum PCMInput {
    enum InputError: Error { case invalidFloat32PCM }

    // Harness interchange format: mono 16 kHz little-endian float32 samples.
    static func read(_ path: String) throws -> [Float] {
        let data = try Data(contentsOf: URL(fileURLWithPath: path))
        guard !data.isEmpty, data.count.isMultiple(of: MemoryLayout<UInt32>.size) else {
            throw InputError.invalidFloat32PCM
        }
        let samples: [Float] = data.withUnsafeBytes { bytes in
            stride(from: 0, to: data.count, by: MemoryLayout<UInt32>.size).map {
                Float(bitPattern: UInt32(littleEndian: bytes.loadUnaligned(fromByteOffset: $0, as: UInt32.self)))
            }
        }
        guard samples.allSatisfy({ $0.isFinite && abs($0) <= 1 }) else {
            throw InputError.invalidFloat32PCM
        }
        return samples
    }
}
