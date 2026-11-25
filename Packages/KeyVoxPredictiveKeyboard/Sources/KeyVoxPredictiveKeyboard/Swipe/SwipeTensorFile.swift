import Foundation

/// A swipe model's exported weight file, memory-mapped: a 4-byte magic, then little-endian
/// `UInt32` version, config count, and config values, a `UInt32` tensor count, and per tensor a
/// `UInt16` name length, the ASCII name, a `UInt8` rank, and its `UInt32` dimensions; then every
/// tensor's fp16 values in table order, row-major (`Tools/KeyVoxSwipeModel/weights_format.py`).
///
/// The weights stay fp16 in the mapped file; inference widens each tensor to `Float` as it uses
/// it, so a loaded model takes no memory of its own.
struct SwipeTensorFile: @unchecked Sendable {
    struct Tensor {
        let shape: [Int]
        fileprivate let offset: Int

        var count: Int { shape.reduce(1, *) }
    }

    static let version: UInt32 = 1

    let config: [Int]
    private let data: Data
    private let tensors: [String: Tensor]
    private let name: String

    init(contentsOf url: URL, magic: String) throws {
        let data = try Data(contentsOf: url, options: .alwaysMapped)
        name = url.lastPathComponent
        var reader = Reader(data: data, name: name)
        guard try reader.bytes(4) == Array(magic.utf8), try reader.uint32() == Self.version else {
            throw PredictiveKeyboardError.invalidSwipeModel(name)
        }
        let configCount = Int(try reader.uint32())
        config = try (0..<configCount).map { _ in Int(try reader.uint32()) }
        let tensorCount = Int(try reader.uint32())
        var table: [(name: String, shape: [Int])] = []
        for _ in 0..<tensorCount {
            let length = Int(try reader.uint16())
            guard let tensorName = String(bytes: try reader.bytes(length), encoding: .ascii) else {
                throw PredictiveKeyboardError.invalidSwipeModel(name)
            }
            let rank = Int(try reader.bytes(1)[0])
            table.append((tensorName, try (0..<rank).map { _ in Int(try reader.uint32()) }))
        }
        var tensors: [String: Tensor] = [:]
        var offset = reader.offset
        for entry in table {
            let tensor = Tensor(shape: entry.shape, offset: offset)
            tensors[entry.name] = tensor
            offset += tensor.count * MemoryLayout<UInt16>.size
        }
        guard offset == data.count else { throw PredictiveKeyboardError.invalidSwipeModel(name) }
        self.data = data
        self.tensors = tensors
    }

    /// The tensor `name`, which must have `shape`.
    func tensor(_ tensorName: String, shape: [Int]) throws -> Tensor {
        guard let tensor = tensors[tensorName], tensor.shape == shape else {
            throw PredictiveKeyboardError.invalidSwipeModel("\(name): \(tensorName)")
        }
        return tensor
    }

    /// Writes `tensor`'s values, widened to `Float`, to `destination`.
    func widen(_ tensor: Tensor, into destination: UnsafeMutablePointer<Float>) {
        data.withUnsafeBytes { raw in
            SwipeMath.widenHalfPrecision(raw.baseAddress! + tensor.offset, count: tensor.count, into: destination)
        }
    }

    /// `tensor`'s values widened to `Float`.
    func values(_ tensor: Tensor) -> [Float] {
        [Float](unsafeUninitializedCapacity: tensor.count) { buffer, initialized in
            widen(tensor, into: buffer.baseAddress!)
            initialized = tensor.count
        }
    }

    private struct Reader {
        let data: Data
        let name: String
        var offset = 0

        mutating func bytes(_ count: Int) throws -> [UInt8] {
            guard count >= 0, offset + count <= data.count else {
                throw PredictiveKeyboardError.invalidSwipeModel(name)
            }
            defer { offset += count }
            return [UInt8](data[data.startIndex + offset..<data.startIndex + offset + count])
        }

        mutating func uint32() throws -> UInt32 {
            try bytes(4).reversed().reduce(0) { $0 << 8 | UInt32($1) }
        }

        mutating func uint16() throws -> UInt16 {
            try bytes(2).reversed().reduce(0) { $0 << 8 | UInt16($1) }
        }
    }
}
