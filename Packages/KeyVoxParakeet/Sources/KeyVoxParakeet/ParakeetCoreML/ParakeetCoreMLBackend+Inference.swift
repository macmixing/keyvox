import Foundation
import CoreML

extension ParakeetCoreMLBackend {
    func runDecoder(targetID: Int32, state: DecoderState) throws -> DecoderStep {
        let targets = try makeInt32Array(shape: [1, 1])
        set(targetID, in: targets, at: [0, 0])

        let targetLength = try makeInt32Array(shape: [1])
        set(Int32(1), in: targetLength, at: [0])

        let features = try decoderModel.prediction(
            from: MLDictionaryFeatureProvider(
                dictionary: [
                    "targets": MLFeatureValue(multiArray: targets),
                    "target_length": MLFeatureValue(multiArray: targetLength),
                    "h_in": MLFeatureValue(multiArray: state.hidden),
                    "c_in": MLFeatureValue(multiArray: state.cell),
                ]
            )
        )

        return DecoderStep(
            output: try requireMultiArray(named: "decoder", from: features),
            state: DecoderState(
                hidden: try requireMultiArray(named: "h_out", from: features),
                cell: try requireMultiArray(named: "c_out", from: features)
            )
        )
    }

    func runJointDecision(encoderStep: MLMultiArray, decoderStep: MLMultiArray) throws -> JointDecision {
        let features = try jointModel.prediction(
            from: MLDictionaryFeatureProvider(
                dictionary: [
                    "encoder_step": MLFeatureValue(multiArray: encoderStep),
                    "decoder_step": MLFeatureValue(multiArray: decoderStep),
                ]
            )
        )

        let tokenID = try requireMultiArray(named: "token_id", from: features)
        let tokenProbability = try requireMultiArray(named: "token_prob", from: features)
        let duration = try requireMultiArray(named: "duration", from: features)

        return JointDecision(
            tokenID: int32Value(in: tokenID, at: [0, 0, 0]),
            tokenProbability: float32Value(in: tokenProbability, at: [0, 0, 0]),
            duration: int32Value(in: duration, at: [0, 0, 0])
        )
    }

    func normalizeDecoderProjection(_ projection: MLMultiArray, into destination: MLMultiArray) throws {
        let shape = projection.shape.map(\.intValue)
        guard shape.count == 3, shape[0] == 1 else {
            throw ParakeetError.transcriptionFailed(code: -1, message: "invalid_decoder_shape")
        }

        let hiddenAxis: Int
        if shape[2] == Constants.decoderHiddenSize {
            hiddenAxis = 2
        } else if shape[1] == Constants.decoderHiddenSize {
            hiddenAxis = 1
        } else {
            throw ParakeetError.transcriptionFailed(code: -1, message: "decoder_hidden_size_mismatch")
        }

        let timeAxis = hiddenAxis == 2 ? 1 : 2
        guard shape[timeAxis] == 1 else {
            throw ParakeetError.transcriptionFailed(code: -1, message: "invalid_decoder_time_axis")
        }

        let projectionStrides = projection.strides.map(\.intValue)
        let hiddenStride = projectionStrides[hiddenAxis]
        try Self.copyNormalizedDecoderProjection(
            projection,
            hiddenAxis: hiddenAxis,
            into: destination,
            hiddenStride: hiddenStride
        )
    }

    func requireMultiArray(named featureName: String, from provider: MLFeatureProvider) throws -> MLMultiArray {
        guard let value = provider.featureValue(for: featureName)?.multiArrayValue else {
            throw ParakeetError.transcriptionFailed(code: -1, message: featureName)
        }
        return value
    }

    static func copyNormalizedDecoderProjection(
        _ projection: MLMultiArray,
        hiddenAxis: Int,
        into destination: MLMultiArray,
        hiddenStride: Int? = nil
    ) throws {
        guard destination.strides.count > 1 else {
            throw ParakeetError.transcriptionFailed(code: -1, message: "invalid_decoder_destination_shape")
        }

        let resolvedHiddenStride = hiddenStride ?? projection.strides.map(\.intValue)[hiddenAxis]
        let destinationStride = destination.strides[1].intValue
        guard resolvedHiddenStride >= 0, destinationStride >= 0 else {
            throw ParakeetError.transcriptionFailed(code: -1, message: "negative_decoder_stride")
        }

        let maxSourceIndex = (Constants.decoderHiddenSize - 1) * resolvedHiddenStride
        let maxDestinationIndex = (Constants.decoderHiddenSize - 1) * destinationStride
        guard maxSourceIndex < projection.count else {
            throw ParakeetError.transcriptionFailed(code: -1, message: "decoder_projection_buffer_too_small")
        }
        guard maxDestinationIndex < destination.count else {
            throw ParakeetError.transcriptionFailed(code: -1, message: "decoder_destination_buffer_too_small")
        }

        for hiddenIndex in 0..<Constants.decoderHiddenSize {
            let sourceIndex = hiddenIndex * resolvedHiddenStride
            let destinationIndex = hiddenIndex * destinationStride
            let value = try Self.floatValue(in: projection, atLinearIndex: sourceIndex)
            try Self.setFloatValue(value, in: destination, atLinearIndex: destinationIndex)
        }
    }
}
