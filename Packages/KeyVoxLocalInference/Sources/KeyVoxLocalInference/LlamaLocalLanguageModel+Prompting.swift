import Foundation
@preconcurrency import llama

extension LlamaLocalLanguageModel {
    func formattedPrompt(
        for request: LocalLanguageModelGenerationRequest,
        loadedModel: LlamaLoadedModel
    ) throws -> String {
        guard request.usesChatTemplate else {
            return request.prompt
        }

        if let systemPrompt = request.systemPrompt, let userPrompt = request.userPrompt {
            return try chatPrompt(systemPrompt: systemPrompt, userPrompt: userPrompt, loadedModel: loadedModel)
        }

        return try chatPrompt(userPrompt: request.prompt, loadedModel: loadedModel)
    }

    func chatPrompt(userPrompt: String, loadedModel: LlamaLoadedModel) throws -> String {
        try chatPrompt(messages: [("user", userPrompt)], loadedModel: loadedModel)
    }

    func chatPrompt(
        systemPrompt: String,
        userPrompt: String,
        loadedModel: LlamaLoadedModel
    ) throws -> String {
        try chatPrompt(
            messages: [
                ("system", systemPrompt),
                ("user", userPrompt)
            ],
            loadedModel: loadedModel
        )
    }

    func chatPrompt(
        messages: [(role: String, content: String)],
        loadedModel: LlamaLoadedModel
    ) throws -> String {
        let template = llama_model_chat_template(loadedModel.model, nil)
        let requiredLength = try withChatMessages(messages) { chatMessages in
            var mutableMessages = chatMessages
            return llama_chat_apply_template(template, &mutableMessages, mutableMessages.count, true, nil, 0)
        }

        guard requiredLength >= 0 else {
            throw LocalLanguageModelError.tokenizerFailed
        }

        var buffer = [CChar](repeating: 0, count: Int(requiredLength) + 1)
        let writtenLength = try withChatMessages(messages) { chatMessages in
            var mutableMessages = chatMessages
            return llama_chat_apply_template(template, &mutableMessages, mutableMessages.count, true, &buffer, Int32(buffer.count))
        }

        guard writtenLength >= 0 else {
            throw LocalLanguageModelError.tokenizerFailed
        }

        return String(decoding: buffer.prefix(Int(writtenLength)).map(UInt8.init(bitPattern:)), as: UTF8.self)
    }

    func withChatMessages<T>(
        _ messages: [(role: String, content: String)],
        _ body: ([llama_chat_message]) throws -> T
    ) throws -> T {
        var chatMessages: [llama_chat_message] = []
        chatMessages.reserveCapacity(messages.count)

        func appendMessage(at index: Int) throws -> T {
            guard index < messages.count else {
                return try body(chatMessages)
            }

            return try messages[index].role.withCString { rolePointer in
                try messages[index].content.withCString { contentPointer in
                    chatMessages.append(llama_chat_message(role: rolePointer, content: contentPointer))
                    defer { _ = chatMessages.popLast() }
                    return try appendMessage(at: index + 1)
                }
            }
        }

        return try appendMessage(at: 0)
    }
}
