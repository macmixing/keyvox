import Foundation
import KeyVoxLocalInference

@MainActor
final class LocalRewriteInferenceService {
    private let modelURLProvider: () -> URL?
    private var loadedModelURL: URL?
    private var loadedModel: LlamaCPULanguageModel?

    init(modelURLProvider: @escaping () -> URL?) {
        self.modelURLProvider = modelURLProvider
    }

    func model() throws -> LlamaCPULanguageModel {
        guard let modelURL = modelURLProvider() else {
            throw LocalRewriteInferenceServiceError.modelNotInstalled
        }

        if loadedModelURL != modelURL {
            loadedModel = LlamaCPULanguageModel(modelURL: modelURL)
            loadedModelURL = modelURL
        }

        guard let loadedModel else {
            throw LocalRewriteInferenceServiceError.modelNotInstalled
        }

        return loadedModel
    }

    func unload() async {
        let currentModel = loadedModel
        loadedModel = nil
        loadedModelURL = nil
        await currentModel?.unload()
    }
}

enum LocalRewriteInferenceServiceError: Error {
    case modelNotInstalled
}
