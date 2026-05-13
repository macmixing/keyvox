import Foundation
@preconcurrency import llama

extension LlamaLocalLanguageModel {
    func tokenize(
        _ text: String,
        loadedModel: LlamaLoadedModel,
        addSpecial: Bool,
        parseSpecial: Bool
    ) throws -> [llama_token] {
        let tokenCapacity = text.utf8.count + 8
        var tokens = [llama_token](repeating: 0, count: max(tokenCapacity, 1))

        let tokenCount = text.withCString { cString in
            llama_tokenize(
                loadedModel.vocab,
                cString,
                Int32(strlen(cString)),
                &tokens,
                Int32(tokens.count),
                addSpecial,
                parseSpecial
            )
        }

        if tokenCount < 0 {
            tokens = [llama_token](repeating: 0, count: Int(-tokenCount))
            let retryCount = text.withCString { cString in
                llama_tokenize(
                    loadedModel.vocab,
                    cString,
                    Int32(strlen(cString)),
                    &tokens,
                    Int32(tokens.count),
                    addSpecial,
                    parseSpecial
                )
            }
            guard retryCount >= 0 else {
                throw LocalLanguageModelError.tokenizerFailed
            }
            return Array(tokens.prefix(Int(retryCount)))
        }

        return Array(tokens.prefix(Int(tokenCount)))
    }

    func decode(
        tokens: [llama_token],
        startingAt startPosition: Int32,
        context: OpaquePointer,
        needsLogits: Bool
    ) throws -> Int32 {
        guard !tokens.isEmpty else { return startPosition }

        var batch = llama_batch_init(Int32(tokens.count), 0, 1)
        defer {
            llama_batch_free(batch)
        }

        batch.n_tokens = Int32(tokens.count)
        for (index, token) in tokens.enumerated() {
            batch.token[index] = token
            batch.pos[index] = startPosition + Int32(index)
            batch.n_seq_id[index] = 1
            batch.seq_id[index]?[0] = 0
            batch.logits[index] = 0
        }
        if needsLogits {
            batch.logits[tokens.count - 1] = 1
        }

        let status = llama_decode(context, batch)
        guard status == 0 else {
            throw LocalLanguageModelError.decodeFailed(code: status)
        }
        return startPosition + Int32(tokens.count)
    }

    func decodePrefill(tokens: [llama_token], context: OpaquePointer) throws -> Int32 {
        guard !tokens.isEmpty else { return 0 }

        let batchLimit = max(1, Int(llama_n_batch(context)))
        var currentPosition: Int32 = 0
        var startIndex = tokens.startIndex

        while startIndex < tokens.endIndex {
            let remainingCount = tokens.distance(from: startIndex, to: tokens.endIndex)
            let chunkCount = min(batchLimit, remainingCount)
            let endIndex = tokens.index(startIndex, offsetBy: chunkCount)
            let isFinalChunk = endIndex == tokens.endIndex
            currentPosition = try decode(
                tokens: Array(tokens[startIndex..<endIndex]),
                startingAt: currentPosition,
                context: context,
                needsLogits: isFinalChunk
            )
            startIndex = endIndex
        }

        return currentPosition
    }

    func tokenText(_ token: llama_token, vocab: OpaquePointer) -> String {
        var buffer = [CChar](repeating: 0, count: 128)
        let count = llama_token_to_piece(
            vocab,
            token,
            &buffer,
            Int32(buffer.count),
            0,
            false
        )

        if count < 0 {
            buffer = [CChar](repeating: 0, count: Int(-count))
            let retryCount = llama_token_to_piece(
                vocab,
                token,
                &buffer,
                Int32(buffer.count),
                0,
                false
            )
            guard retryCount > 0 else { return "" }
            return String(decoding: buffer.prefix(Int(retryCount)).map(UInt8.init(bitPattern:)), as: UTF8.self)
        }

        guard count > 0 else { return "" }
        return String(decoding: buffer.prefix(Int(count)).map(UInt8.init(bitPattern:)), as: UTF8.self)
    }
}
