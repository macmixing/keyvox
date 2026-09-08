import Foundation

enum CapturedAudio {
    static func read(path: String) throws -> [Float] {
        let data = try Data(contentsOf: URL(fileURLWithPath: path))
        guard data.count.isMultiple(of: MemoryLayout<Float>.size) else { throw CocoaError(.fileReadCorruptFile) }
        return try data.withUnsafeBytes { bytes in
            try stride(from: 0, to: data.count, by: MemoryLayout<UInt32>.size).map { offset in
                let value = Float(bitPattern: UInt32(littleEndian: bytes.loadUnaligned(fromByteOffset: offset, as: UInt32.self)))
                guard value.isFinite else { throw CocoaError(.fileReadCorruptFile) }
                return value
            }
        }
    }
}
