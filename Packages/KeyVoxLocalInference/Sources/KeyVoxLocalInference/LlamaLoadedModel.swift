import Foundation
@preconcurrency import llama

final class LlamaLoadedModel {
    let model: OpaquePointer
    let context: OpaquePointer
    let vocab: OpaquePointer
    let adapter: OpaquePointer?
    var lastLoadDuration: TimeInterval?

    init(
        model: OpaquePointer,
        context: OpaquePointer,
        vocab: OpaquePointer,
        adapter: OpaquePointer?,
        lastLoadDuration: TimeInterval?
    ) {
        self.model = model
        self.context = context
        self.vocab = vocab
        self.adapter = adapter
        self.lastLoadDuration = lastLoadDuration
    }

    deinit {
        if let adapter {
            llama_set_adapters_lora(context, nil, 0, nil)
            llama_adapter_lora_free(adapter)
        }
        llama_free(context)
        llama_model_free(model)
    }
}
