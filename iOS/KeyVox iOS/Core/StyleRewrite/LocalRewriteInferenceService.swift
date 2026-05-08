import Foundation
import KeyVoxLocalInference

@MainActor
final class LocalRewriteInferenceService {
    private let modelURLProvider: () -> URL?
    private let adapterURLProvider: () -> URL?
    private var loadedModelURL: URL?
    private var loadedAdapterURL: URL?
    private var loadedModel: LlamaCPULanguageModel?

    init(
        modelURLProvider: @escaping () -> URL?,
        adapterURLProvider: @escaping () -> URL? = { nil }
    ) {
        self.modelURLProvider = modelURLProvider
        self.adapterURLProvider = adapterURLProvider
    }

    func model(usesPolishedLoRA: Bool = false) throws -> LlamaCPULanguageModel {
        guard let modelURL = modelURLProvider() else {
            throw LocalRewriteInferenceServiceError.modelNotInstalled
        }
        let adapterURL: URL?
        if usesPolishedLoRA {
            guard let polishedAdapterURL = adapterURLProvider() else {
                throw LocalRewriteInferenceServiceError.polishedAdapterNotInstalled
            }
            adapterURL = polishedAdapterURL
        } else {
            adapterURL = nil
        }

        if loadedModelURL != modelURL || loadedAdapterURL != adapterURL {
            loadedModel = LlamaCPULanguageModel(modelURL: modelURL, adapterURL: adapterURL)
            loadedModelURL = modelURL
            loadedAdapterURL = adapterURL
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
        loadedAdapterURL = nil
        await currentModel?.unload()
    }
}

enum LocalRewriteInferenceServiceError: Error {
    case modelNotInstalled
    case polishedAdapterNotInstalled
}
