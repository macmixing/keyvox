import Foundation
import KeyVoxLocalInference

enum LocalRewriteAdapterKind {
    case polished
    case casual
}

@MainActor
final class LocalRewriteInferenceService {
    typealias AdapterURLProvider = (LocalRewriteAdapterKind) -> URL?

    private let modelURLProvider: () -> URL?
    private let adapterURLProvider: AdapterURLProvider
    private var loadedModelURL: URL?
    private var loadedAdapterURL: URL?
    private var loadedModel: LlamaLocalLanguageModel?

    init(
        modelURLProvider: @escaping () -> URL?,
        adapterURLProvider: @escaping AdapterURLProvider = { _ in nil }
    ) {
        self.modelURLProvider = modelURLProvider
        self.adapterURLProvider = adapterURLProvider
    }

    func model(adapter: LocalRewriteAdapterKind? = nil) throws -> LlamaLocalLanguageModel {
        guard let modelURL = modelURLProvider() else {
            throw LocalRewriteInferenceServiceError.modelNotInstalled
        }
        let adapterURL: URL?
        if let adapter {
            guard let resolvedAdapterURL = adapterURLProvider(adapter) else {
                throw LocalRewriteInferenceServiceError.adapterNotInstalled(adapter)
            }
            adapterURL = resolvedAdapterURL
        } else {
            adapterURL = nil
        }

        if loadedModelURL != modelURL || loadedAdapterURL != adapterURL {
            loadedModel = LlamaLocalLanguageModel(modelURL: modelURL, adapterURL: adapterURL)
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
    case adapterNotInstalled(LocalRewriteAdapterKind)
}
