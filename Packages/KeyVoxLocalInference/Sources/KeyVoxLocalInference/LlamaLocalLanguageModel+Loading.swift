import Foundation
@preconcurrency import llama

extension LlamaLocalLanguageModel {
    func loadModelIfNeeded(configuration: LocalLanguageModelConfiguration) throws -> LlamaLoadedModel {
        if let loadedModel {
            return loadedModel
        }

        guard fileManager.fileExists(atPath: modelURL.path) else {
            throw LocalLanguageModelError.modelFileMissing
        }

        _ = Self.initializeCoreRuntime

        let loaded = try loadModelWithFallbackIfNeeded(configuration: configuration)
        loadedModel = loaded
        return loaded
    }

    func loadModelWithFallbackIfNeeded(configuration: LocalLanguageModelConfiguration) throws -> LlamaLoadedModel {
        let gpuSupport = Self.supportsGPUOffloadForCurrentPlatform()
        let requestedGPULayers = requestedGPULayerCount(gpuSupport: gpuSupport)
        let deviceSummary = gpuSupport ? Self.backendDeviceSummaryForDiagnostics() : "skipped"

        if let requestedGPULayers {
            diagnosticLog(
                "gpu-offload mode=\(gpuOffloadMode.logLabel) supported=\(gpuSupport) action=attempt layers=\(requestedGPULayers) devices=\(deviceSummary)"
            )

            do {
                let loaded = try loadModel(
                    configuration: configuration,
                    gpuLayerCount: requestedGPULayers
                )
                diagnosticLog(
                    "gpu-offload mode=\(gpuOffloadMode.logLabel) backend=gpu layers=\(requestedGPULayers)"
                )
                return loaded
            } catch LocalLanguageModelError.modelLoadFailed {
                diagnosticLog(
                    "gpu-offload mode=\(gpuOffloadMode.logLabel) fallback=cpu reason=modelLoadFailed"
                )
            } catch LocalLanguageModelError.contextCreateFailed {
                diagnosticLog(
                    "gpu-offload mode=\(gpuOffloadMode.logLabel) fallback=cpu reason=contextCreateFailed"
                )
            }
        } else if gpuOffloadMode != .disabled {
            diagnosticLog(
                "gpu-offload mode=\(gpuOffloadMode.logLabel) supported=\(gpuSupport) action=cpu devices=\(deviceSummary)"
            )
        }

        let loaded = try loadModel(configuration: configuration, gpuLayerCount: 0)
        diagnosticLog("gpu-offload mode=\(gpuOffloadMode.logLabel) backend=cpu layers=0")
        return loaded
    }

    func loadModel(
        configuration: LocalLanguageModelConfiguration,
        gpuLayerCount: Int32
    ) throws -> LlamaLoadedModel {
        let start = Date()
        var modelParameters = llama_model_default_params()
        modelParameters.n_gpu_layers = gpuLayerCount
        modelParameters.use_mmap = true
        modelParameters.use_mlock = false
        modelParameters.check_tensors = true
        modelParameters.use_extra_bufts = false
        modelParameters.no_host = false

        let model = modelURL.path.withCString { llama_model_load_from_file($0, modelParameters) }

        guard let model else {
            throw LocalLanguageModelError.modelLoadFailed
        }

        var contextParameters = llama_context_default_params()
        contextParameters.n_ctx = UInt32(max(configuration.contextTokenLimit, 1))
        contextParameters.n_batch = UInt32(max(configuration.batchTokenCount, 1))
        contextParameters.n_ubatch = UInt32(max(configuration.batchTokenCount, 1))
        contextParameters.n_threads = Int32(max(configuration.threadCount, 1))
        contextParameters.n_threads_batch = Int32(max(configuration.batchThreadCount, 1))
        contextParameters.offload_kqv = gpuLayerCount != 0
        contextParameters.op_offload = gpuLayerCount != 0
        contextParameters.embeddings = false

        guard let context = llama_init_from_model(model, contextParameters) else {
            llama_model_free(model)
            throw LocalLanguageModelError.contextCreateFailed
        }

        let adapter = try loadAdapterIfNeeded(model: model, context: context)

        return LlamaLoadedModel(
            model: model,
            context: context,
            vocab: llama_model_get_vocab(model),
            adapter: adapter,
            lastLoadDuration: Date().timeIntervalSince(start)
        )
    }

    func requestedGPULayerCount(gpuSupport: Bool) -> Int32? {
        guard gpuSupport else { return nil }

        #if os(macOS)
        switch gpuOffloadMode {
        case .disabled:
            return nil
        case .automatic, .allLayers:
            return -1
        case .layerCount(let layerCount):
            return max(layerCount, 0)
        }
        #else
        return nil
        #endif
    }

    static func supportsGPUOffloadForCurrentPlatform() -> Bool {
        #if os(macOS)
        let osVersion = ProcessInfo.processInfo.operatingSystemVersion
        guard osVersion.majorVersion >= 15 else {
            return false
        }

        guard !ProcessInfo.processInfo.isRunningUnderXCTest else {
            return false
        }

        _ = Self.initializeGPUBackends
        return llama_supports_gpu_offload()
        #else
        return false
        #endif
    }

    static func backendDeviceSummaryForDiagnostics() -> String {
        #if os(macOS)
        _ = Self.initializeGPUBackends
        let deviceCount = ggml_backend_dev_count()
        guard deviceCount > 0 else {
            return "count=0"
        }

        var entries: [String] = []
        for index in 0..<deviceCount {
            guard let device = ggml_backend_dev_get(index) else {
                entries.append("\(index):missing")
                continue
            }

            let name = ggml_backend_dev_name(device).map { String(cString: $0) } ?? "unknown"
            let description = ggml_backend_dev_description(device).map { String(cString: $0) } ?? "unknown"
            entries.append("\(index):\(name):\(description)")
        }
        return "count=\(deviceCount) [\(entries.joined(separator: ","))]"
        #else
        return "unavailable"
        #endif
    }

    func loadAdapterIfNeeded(model: OpaquePointer, context: OpaquePointer) throws -> OpaquePointer? {
        guard let adapterURL else {
            return nil
        }

        guard fileManager.fileExists(atPath: adapterURL.path) else {
            llama_free(context)
            llama_model_free(model)
            throw LocalLanguageModelError.adapterFileMissing
        }

        let adapter = adapterURL.path.withCString { path in
            llama_adapter_lora_init(model, path)
        }

        guard let adapter else {
            llama_free(context)
            llama_model_free(model)
            throw LocalLanguageModelError.adapterLoadFailed
        }

        var adapters: [OpaquePointer?] = [adapter]
        var scales: [Float] = [adapterScale]
        let status = adapters.withUnsafeMutableBufferPointer { adapterBuffer in
            scales.withUnsafeMutableBufferPointer { scaleBuffer in
                llama_set_adapters_lora(
                    context,
                    adapterBuffer.baseAddress,
                    adapterBuffer.count,
                    scaleBuffer.baseAddress
                )
            }
        }

        guard status == 0 else {
            llama_adapter_lora_free(adapter)
            llama_free(context)
            llama_model_free(model)
            throw LocalLanguageModelError.adapterAttachFailed(code: status)
        }

        return adapter
    }
}
