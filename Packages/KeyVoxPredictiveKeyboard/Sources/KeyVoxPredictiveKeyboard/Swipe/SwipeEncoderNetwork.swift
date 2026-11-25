import Foundation
// Android's C library supplies the `Float` math functions Foundation brings in elsewhere.
#if canImport(Android)
import Android
#endif

/// The swipe encoder (`swipe_encoder.kvsw`): a dilated temporal convolution network that reads a
/// resampled swipe and, for every output frame, scores each key of the layout it is given by
/// that key's center alone, as `Tools/KeyVoxSwipeModel/exported_model.py` (`encode`, `frames`)
/// runs it.
///
/// Each block is a dilated depthwise convolution, a gated expansion, a global response norm, a
/// projection, and a squeeze-and-excite, added to its input; batch normalizations are already
/// folded into the convolutions before them.
struct SwipeEncoderNetwork: Sendable {
    /// What the encoder says about one swipe, frame-major: per frame the log-probabilities
    /// (blank first, then each key in the order given), the cosine coefficients, and the gate
    /// probability.
    struct Frames {
        let count: Int
        let width: Int
        let values: [Float]
    }

    private struct Block {
        let dilation: Int
        let depthwiseWeight: SwipeTensorFile.Tensor
        let depthwiseBias: SwipeTensorFile.Tensor
        let expandWeight: SwipeTensorFile.Tensor
        let expandBias: SwipeTensorFile.Tensor
        let responseGamma: SwipeTensorFile.Tensor
        let responseBeta: SwipeTensorFile.Tensor
        let projectWeight: SwipeTensorFile.Tensor
        let projectBias: SwipeTensorFile.Tensor
        let reduceWeight: SwipeTensorFile.Tensor
        let reduceBias: SwipeTensorFile.Tensor
        let exciteWeight: SwipeTensorFile.Tensor
        let exciteBias: SwipeTensorFile.Tensor
    }

    static let magic = "KVSW"
    static let fileName = "swipe_encoder.kvsw"
    /// How many channels a squeeze-and-excite squeezes into one.
    private static let exciteReduction = 8
    private static let responseFloor: Float = 1e-6

    /// How many resampled points a swipe is read as.
    let points: Int
    /// How many cosine coefficients each frame predicts.
    let coefficientCount: Int
    private let file: SwipeTensorFile
    private let width: Int
    private let hidden: Int
    private let kernel: Int
    private let headWidth: Int
    private let basis: Int
    private let inputScale: SwipeTensorFile.Tensor
    private let inputShift: SwipeTensorFile.Tensor
    private let stemWeight: SwipeTensorFile.Tensor
    private let stemBias: SwipeTensorFile.Tensor
    private let blocks: [Block]
    private let adapterWeight: SwipeTensorFile.Tensor
    private let adapterBias: SwipeTensorFile.Tensor
    private let coefficientsWeight: SwipeTensorFile.Tensor
    private let coefficientsBias: SwipeTensorFile.Tensor
    private let gateWeight: SwipeTensorFile.Tensor
    private let gateBias: SwipeTensorFile.Tensor

    init(contentsOf url: URL) throws {
        let file = try SwipeTensorFile(contentsOf: url, magic: Self.magic)
        let config = file.config
        guard config.count >= 7, config.count == 7 + config[6], config[0] % 2 == 0,
              config[2] > 0, config[3] % 2 == 1, config[1] % Self.exciteReduction == 0 else {
            throw PredictiveKeyboardError.invalidSwipeModel(url.lastPathComponent)
        }
        points = config[0]
        width = config[1]
        hidden = config[1] * config[2]
        kernel = config[3]
        headWidth = config[4]
        basis = config[5]
        coefficientCount = basis * basis
        let features = SwipeMotionFeatures.count
        inputScale = try file.tensor("input.scale", shape: [features])
        inputShift = try file.tensor("input.shift", shape: [features])
        stemWeight = try file.tensor("stem.weight", shape: [width, features, kernel])
        stemBias = try file.tensor("stem.bias", shape: [width])
        let width = config[1]
        let hidden = config[1] * config[2]
        let half = hidden / 2
        let squeezed = width / Self.exciteReduction
        blocks = try config[7...].enumerated().map { number, dilation in
            let prefix = "block\(number)."
            return Block(
                dilation: dilation,
                depthwiseWeight: try file.tensor(prefix + "depthwise.weight", shape: [config[1], config[3]]),
                depthwiseBias: try file.tensor(prefix + "depthwise.bias", shape: [config[1]]),
                expandWeight: try file.tensor(prefix + "expand.weight", shape: [hidden, width]),
                expandBias: try file.tensor(prefix + "expand.bias", shape: [hidden]),
                responseGamma: try file.tensor(prefix + "response.gamma", shape: [half]),
                responseBeta: try file.tensor(prefix + "response.beta", shape: [half]),
                projectWeight: try file.tensor(prefix + "project.weight", shape: [width, half]),
                projectBias: try file.tensor(prefix + "project.bias", shape: [width]),
                reduceWeight: try file.tensor(prefix + "excite.reduce.weight", shape: [squeezed, width]),
                reduceBias: try file.tensor(prefix + "excite.reduce.bias", shape: [squeezed]),
                exciteWeight: try file.tensor(prefix + "excite.expand.weight", shape: [width, squeezed]),
                exciteBias: try file.tensor(prefix + "excite.expand.bias", shape: [width])
            )
        }
        adapterWeight = try file.tensor("adapter.weight", shape: [headWidth, width, 2])
        adapterBias = try file.tensor("adapter.bias", shape: [headWidth])
        coefficientsWeight = try file.tensor("coefficients.weight", shape: [coefficientCount, headWidth])
        coefficientsBias = try file.tensor("coefficients.bias", shape: [coefficientCount])
        gateWeight = try file.tensor("gate.weight", shape: [1, headWidth])
        gateBias = try file.tensor("gate.bias", shape: [1])
        self.file = file
    }

    /// The frames for `path`, `points` x, y pairs in the model's frame, scoring keys centered at
    /// `keyCenters`.
    func frames(path: [Float], keyCenters: [(x: Float, y: Float)]) -> Frames {
        let length = points
        var x = SwipeMotionFeatures.features(of: path)
        let scale = file.values(inputScale)
        let shift = file.values(inputShift)
        for feature in 0..<SwipeMotionFeatures.count {
            for point in 0..<length {
                x[feature * length + point] = x[feature * length + point] * scale[feature] + shift[feature]
            }
        }
        x = convolve(x, channels: SwipeMotionFeatures.count, weight: stemWeight, bias: stemBias)
        for index in x.indices { x[index] = SwipeMath.hardSwish(x[index]) }
        for block in blocks {
            run(block, on: &x)
        }
        let head = adapt(x)
        return frames(head: head, keyCenters: keyCenters)
    }

    /// A zero-padded "same" convolution of [channels, points] values to [width, points].
    private func convolve(
        _ x: [Float],
        channels: Int,
        weight: SwipeTensorFile.Tensor,
        bias: SwipeTensorFile.Tensor
    ) -> [Float] {
        let length = points
        let reach = kernel / 2
        var columns = [Float](repeating: 0, count: channels * kernel * length)
        for channel in 0..<channels {
            for tap in 0..<kernel {
                let row = (channel * kernel + tap) * length
                for point in 0..<length {
                    let source = point + tap - reach
                    if source >= 0, source < length {
                        columns[row + point] = x[channel * length + source]
                    }
                }
            }
        }
        return linear(columns, inputs: channels * kernel, outputs: width, weight: weight, bias: bias)
    }

    /// `weight` ([outputs, inputs]) times `x` ([inputs, points]) plus `bias` per output.
    private func linear(
        _ x: [Float],
        inputs: Int,
        outputs: Int,
        weight: SwipeTensorFile.Tensor,
        bias: SwipeTensorFile.Tensor,
        columns: Int? = nil
    ) -> [Float] {
        let length = columns ?? points
        let weights = file.values(weight)
        let biases = file.values(bias)
        var output = [Float](repeating: 0, count: outputs * length)
        for row in 0..<outputs {
            for point in 0..<length { output[row * length + point] = biases[row] }
        }
        weights.withUnsafeBufferPointer { a in
            x.withUnsafeBufferPointer { b in
                output.withUnsafeMutableBufferPointer { c in
                    SwipeMath.multiply(
                        a.baseAddress!, b.baseAddress!, into: c.baseAddress!,
                        m: outputs, n: length, k: inputs, accumulating: true
                    )
                }
            }
        }
        return output
    }

    private func run(_ block: Block, on x: inout [Float]) {
        let length = points
        let weight = file.values(block.depthwiseWeight)
        let bias = file.values(block.depthwiseBias)
        let reach = block.dilation * (kernel - 1) / 2
        var y = [Float](repeating: 0, count: width * length)
        for channel in 0..<width {
            for point in 0..<length {
                var total: Float = 0
                for tap in 0..<kernel {
                    let source = point + tap * block.dilation - reach
                    if source >= 0, source < length {
                        total += weight[channel * kernel + tap] * x[channel * length + source]
                    }
                }
                y[channel * length + point] = total + bias[channel]
            }
        }
        let expanded = linear(y, inputs: width, outputs: hidden, weight: block.expandWeight, bias: block.expandBias)
        let half = hidden / 2
        var gated = [Float](repeating: 0, count: half * length)
        for index in 0..<(half * length) {
            gated[index] = expanded[index] * SwipeMath.sigmoid(expanded[half * length + index])
        }
        var energy = [Float](repeating: 0, count: half)
        for channel in 0..<half {
            var total: Float = 0
            for point in 0..<length {
                let value = gated[channel * length + point]
                total += value * value
            }
            energy[channel] = total.squareRoot()
        }
        let meanEnergy = energy.reduce(0, +) / Float(half)
        let gamma = file.values(block.responseGamma)
        let beta = file.values(block.responseBeta)
        for channel in 0..<half {
            let normalized = energy[channel] / (meanEnergy + Self.responseFloor)
            for point in 0..<length {
                let index = channel * length + point
                gated[index] = gamma[channel] * (gated[index] * normalized) + beta[channel] + gated[index]
            }
        }
        var projected = linear(gated, inputs: half, outputs: width, weight: block.projectWeight, bias: block.projectBias)
        let squeezed = width / Self.exciteReduction
        let reduceWeight = file.values(block.reduceWeight)
        let reduceBias = file.values(block.reduceBias)
        let exciteWeight = file.values(block.exciteWeight)
        let exciteBias = file.values(block.exciteBias)
        var means = [Float](repeating: 0, count: width)
        for channel in 0..<width {
            var total: Float = 0
            for point in 0..<length { total += projected[channel * length + point] }
            means[channel] = total / Float(length)
        }
        var reduced = [Float](repeating: 0, count: squeezed)
        for row in 0..<squeezed {
            var total = reduceBias[row]
            for channel in 0..<width { total += reduceWeight[row * width + channel] * means[channel] }
            reduced[row] = max(total, 0)
        }
        for channel in 0..<width {
            var total = exciteBias[channel]
            for row in 0..<squeezed { total += exciteWeight[channel * squeezed + row] * reduced[row] }
            let excite = SwipeMath.sigmoid(total)
            for point in 0..<length {
                let index = channel * length + point
                projected[index] *= excite
                x[index] += projected[index]
            }
        }
    }

    /// The stride-2 adapter to the head, hard-swished: [headWidth, points / 2].
    private func adapt(_ x: [Float]) -> [Float] {
        let length = points
        let frames = length / 2
        var columns = [Float](repeating: 0, count: width * 2 * frames)
        for channel in 0..<width {
            for tap in 0..<2 {
                let row = (channel * 2 + tap) * frames
                for frame in 0..<frames {
                    columns[row + frame] = x[channel * length + frame * 2 + tap]
                }
            }
        }
        var head = linear(
            columns, inputs: width * 2, outputs: headWidth, weight: adapterWeight, bias: adapterBias, columns: frames
        )
        for index in head.indices { head[index] = SwipeMath.hardSwish(head[index]) }
        return head
    }

    private func frames(head: [Float], keyCenters: [(x: Float, y: Float)]) -> Frames {
        let frameCount = points / 2
        let keys = keyCenters.count
        let coefficientWeights = file.values(coefficientsWeight)
        let coefficientBiases = file.values(coefficientsBias)
        let gateWeights = file.values(gateWeight)
        let gateBiases = file.values(gateBias)
        var coefficients = [Float](repeating: 0, count: frameCount * coefficientCount)
        for frame in 0..<frameCount {
            for coefficient in 0..<coefficientCount {
                coefficients[frame * coefficientCount + coefficient] = coefficientBiases[coefficient]
            }
        }
        head.withUnsafeBufferPointer { a in
            coefficientWeights.withUnsafeBufferPointer { b in
                coefficients.withUnsafeMutableBufferPointer { c in
                    SwipeMath.multiply(
                        a.baseAddress!, transposingA: true, b.baseAddress!, transposingB: true,
                        into: c.baseAddress!, m: frameCount, n: coefficientCount, k: headWidth, accumulating: true
                    )
                }
            }
        }
        let keyBasis = Self.keyBasis(keyCenters, basis: basis)
        var logits = [Float](repeating: 0, count: frameCount * keys)
        coefficients.withUnsafeBufferPointer { a in
            keyBasis.withUnsafeBufferPointer { b in
                logits.withUnsafeMutableBufferPointer { c in
                    SwipeMath.multiply(
                        a.baseAddress!, b.baseAddress!, transposingB: true, into: c.baseAddress!,
                        m: frameCount, n: keys, k: coefficientCount
                    )
                }
            }
        }
        let frameWidth = 1 + keys + coefficientCount + 1
        var values = [Float](repeating: 0, count: frameCount * frameWidth)
        logits.withUnsafeMutableBufferPointer { logits in
            for frame in 0..<frameCount {
                var gate = gateBiases[0]
                for channel in 0..<headWidth {
                    gate += head[channel * frameCount + frame] * gateWeights[channel]
                }
                let row = logits.baseAddress! + frame * keys
                SwipeMath.logSoftmax(row, count: keys)
                let keyLogGate = SwipeMath.logSigmoid(gate)
                let output = frame * frameWidth
                values[output] = SwipeMath.logSigmoid(-gate)
                for key in 0..<keys { values[output + 1 + key] = row[key] + keyLogGate }
                for coefficient in 0..<coefficientCount {
                    values[output + 1 + keys + coefficient] = coefficients[frame * coefficientCount + coefficient]
                }
                values[output + frameWidth - 1] = SwipeMath.sigmoid(gate)
            }
        }
        return Frames(count: frameCount, width: frameWidth, values: values)
    }

    /// Each key's cosine basis values, u major then v: [keys, basis * basis].
    private static func keyBasis(_ centers: [(x: Float, y: Float)], basis: Int) -> [Float] {
        var values = [Float](repeating: 0, count: centers.count * basis * basis)
        for (key, center) in centers.enumerated() {
            for u in 0..<basis {
                let alongX = cos(center.x * (Float(u) * Float.pi))
                for v in 0..<basis {
                    values[(key * basis + u) * basis + v] = alongX * cos(center.y * (Float(v) * Float.pi))
                }
            }
        }
        return values
    }
}
