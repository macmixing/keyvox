@preconcurrency import CoreML

extension MLModel {
    func keyVoxPrediction(
        from input: MLFeatureProvider,
        options: MLPredictionOptions = MLPredictionOptions()
    ) async throws -> MLFeatureProvider {
        try await prediction(from: input, options: options)
    }
}
