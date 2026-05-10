import Foundation
import KeyVoxLocalInference

enum MacLocalRewriteAdapterKind {
    case polished
    case casual
}

@MainActor
final class MacLocalRewriteInferenceService {
    typealias AdapterURLProvider = (MacLocalRewriteAdapterKind) -> URL?

    private let modelURLProvider: () -> URL?
    private let adapterURLProvider: AdapterURLProvider
    private var loadedModelURL: URL?
    private var loadedAdapterURL: URL?
    private var loadedModel: LlamaCPULanguageModel?

    init(
        modelURLProvider: @escaping () -> URL?,
        adapterURLProvider: @escaping AdapterURLProvider = { _ in nil }
    ) {
        self.modelURLProvider = modelURLProvider
        self.adapterURLProvider = adapterURLProvider
    }

    func model(adapter: MacLocalRewriteAdapterKind? = nil) throws -> LlamaCPULanguageModel {
        guard let modelURL = modelURLProvider() else {
            throw MacLocalRewriteInferenceServiceError.modelNotInstalled
        }

        let adapterURL: URL?
        if let adapter {
            guard let resolvedAdapterURL = adapterURLProvider(adapter) else {
                throw MacLocalRewriteInferenceServiceError.adapterNotInstalled(adapter)
            }
            adapterURL = resolvedAdapterURL
        } else {
            adapterURL = nil
        }

        if loadedModelURL != modelURL || loadedAdapterURL != adapterURL {
            loadedModel = LlamaCPULanguageModel(modelURL: modelURL, adapterURL: adapterURL)
            loadedModelURL = modelURL
            loadedAdapterURL = adapterURL
        }

        guard let loadedModel else {
            throw MacLocalRewriteInferenceServiceError.modelNotInstalled
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

enum MacLocalRewriteInferenceServiceError: Error {
    case modelNotInstalled
    case adapterNotInstalled(MacLocalRewriteAdapterKind)
}
