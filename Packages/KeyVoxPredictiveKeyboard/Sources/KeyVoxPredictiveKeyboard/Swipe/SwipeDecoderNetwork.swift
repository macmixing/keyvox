import Foundation

/// The swipe decoder (`swipe_decoder.kvsd`): a small feedforward sequential memory network that
/// reads the encoder's frames for one fixed key layout and corrects its log-probabilities, as
/// `Tools/KeyVoxSwipeModel/exported_model.py` (`decode_frames`) runs it.
///
/// Every block projects to a narrow memory, mixes it with a symmetric window of neighboring
/// frames, adds the previous block's memory, and projects back with a residual; the head's
/// output is added to the encoder's log-probabilities and renormalized.
struct SwipeDecoderNetwork: Sendable {
    private struct Block {
        let down: SwipeTensorFile.Tensor
        let memory: SwipeTensorFile.Tensor
        let upWeight: SwipeTensorFile.Tensor
        let upBias: SwipeTensorFile.Tensor
    }

    static let magic = "KVSD"
    static let fileName = "swipe_decoder.kvsd"

    /// How many symbols it scores: the blank and every key of its layout.
    let symbols: Int
    /// How many values each encoder frame it reads holds.
    let inputs: Int
    private let file: SwipeTensorFile
    private let width: Int
    private let bottleneck: Int
    private let memorySpan: Int
    private let projectWeight: SwipeTensorFile.Tensor
    private let projectBias: SwipeTensorFile.Tensor
    private let blocks: [Block]
    private let headWeight: SwipeTensorFile.Tensor
    private let headBias: SwipeTensorFile.Tensor

    init(contentsOf url: URL) throws {
        let file = try SwipeTensorFile(contentsOf: url, magic: Self.magic)
        let config = file.config
        guard config.count == 6 else { throw PredictiveKeyboardError.invalidSwipeModel(url.lastPathComponent) }
        symbols = config[0]
        inputs = config[0] + config[1] + 1
        width = config[2]
        bottleneck = config[3]
        memorySpan = 2 * config[5] + 1
        projectWeight = try file.tensor("project.weight", shape: [config[2], inputs])
        projectBias = try file.tensor("project.bias", shape: [config[2]])
        blocks = try (0..<config[4]).map { number in
            let prefix = "block\(number)."
            return Block(
                down: try file.tensor(prefix + "down.weight", shape: [config[3], config[2]]),
                memory: try file.tensor(prefix + "memory.weight", shape: [config[3], 2 * config[5] + 1]),
                upWeight: try file.tensor(prefix + "up.weight", shape: [config[2], config[3]]),
                upBias: try file.tensor(prefix + "up.bias", shape: [config[2]])
            )
        }
        headWeight = try file.tensor("head.weight", shape: [config[0], config[2]])
        headBias = try file.tensor("head.bias", shape: [config[0]])
        self.file = file
    }

    /// The corrected log-probabilities for `frames`, frame-major: [frames, symbols].
    func logProbabilities(for frames: SwipeEncoderNetwork.Frames) -> [Float] {
        let count = frames.count
        var x = linear(frames.values, rows: count, inputs: inputs, outputs: width, weight: projectWeight, bias: projectBias)
        for index in x.indices { x[index] = max(x[index], 0) }
        var memory: [Float]?
        let reach = memorySpan / 2
        for block in blocks {
            let narrow = linear(x, rows: count, inputs: width, outputs: bottleneck, weight: block.down, bias: nil)
            let window = file.values(block.memory)
            var mixed = narrow
            for frame in 0..<count {
                for channel in 0..<bottleneck {
                    var total: Float = 0
                    for tap in 0..<memorySpan {
                        let source = frame + tap - reach
                        if source >= 0, source < count {
                            total += narrow[source * bottleneck + channel] * window[channel * memorySpan + tap]
                        }
                    }
                    mixed[frame * bottleneck + channel] += total
                }
            }
            if let memory {
                for index in mixed.indices { mixed[index] += memory[index] }
            }
            memory = mixed
            let up = linear(mixed, rows: count, inputs: bottleneck, outputs: width, weight: block.upWeight, bias: block.upBias)
            for index in x.indices { x[index] += max(up[index], 0) }
        }
        var corrected = linear(x, rows: count, inputs: width, outputs: symbols, weight: headWeight, bias: headBias)
        corrected.withUnsafeMutableBufferPointer { corrected in
            for frame in 0..<count {
                let row = corrected.baseAddress! + frame * symbols
                for symbol in 0..<symbols { row[symbol] += frames.values[frame * frames.width + symbol] }
                SwipeMath.logSoftmax(row, count: symbols)
            }
        }
        return corrected
    }

    /// `x` ([rows, inputs]) times the transpose of `weight` ([outputs, inputs]), plus `bias`.
    private func linear(
        _ x: [Float],
        rows: Int,
        inputs: Int,
        outputs: Int,
        weight: SwipeTensorFile.Tensor,
        bias: SwipeTensorFile.Tensor?
    ) -> [Float] {
        let weights = file.values(weight)
        var output = [Float](repeating: 0, count: rows * outputs)
        if let bias {
            let biases = file.values(bias)
            for row in 0..<rows {
                for column in 0..<outputs { output[row * outputs + column] = biases[column] }
            }
        }
        x.withUnsafeBufferPointer { a in
            weights.withUnsafeBufferPointer { b in
                output.withUnsafeMutableBufferPointer { c in
                    SwipeMath.multiply(
                        a.baseAddress!, b.baseAddress!, transposingB: true, into: c.baseAddress!,
                        m: rows, n: outputs, k: inputs, accumulating: true
                    )
                }
            }
        }
        return output
    }
}
