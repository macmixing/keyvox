import Foundation
import KeyVoxWhisper
import Combine
import AVFoundation

class WhisperService: ObservableObject {
    @Published var isTranscribing = false
    @Published var transcriptionText = ""
    @Published private(set) var lastResultWasLikelyNoSpeech = false
    
    private var whisper: Whisper?
    private var dictionaryHintPrompt = ""
    private let noSpeechSegmentProbabilityThreshold: Float = 0.72
    private let noSpeechAverageProbabilityThreshold: Float = 0.80
    private let paragraphChunker = WhisperAudioParagraphChunker()
    // Intentionally disabled while validating phonetic matching without hint bias.
    private let isPromptHintingEnabled = false
    private let suspiciousShortResultMinChunkSeconds: Double = 1.35
    private let suspiciousShortResultMaxWords = 2
    private let suspiciousShortResultMaxNoSpeechProbability: Float = 0.35
    private let retryRelaxedLogprobThreshold: Float = -2.0
    
    /// Pre-loads the model into memory to eliminate cold-start latency.
    func warmup() {
        guard whisper == nil else {
            #if DEBUG
            print("WhisperService: Warmup skipped (model already loaded).")
            #endif
            return
        }
        guard let modelPath = getModelPath() else {
            #if DEBUG
            print("WhisperService: Warmup skipped (model files not found).")
            #endif
            return
        }
        
        #if DEBUG
        print("Warming up Whisper model with optimized settings...")
        #endif
        
        let params = WhisperParams.default
        params.language = .auto
        params.n_threads = 4 // Optimal for M-series P-cores (prevent oversubscription)
        params.no_context = true
        params.print_timestamps = false
        params.suppress_blank = true
        params.suppress_non_speech_tokens = true
        params.temperature = 0.0
        params.temperature_inc = 0.0
        params.no_speech_thold = 0.6
        params.logprob_thold = -0.8
        params.initialPrompt = isPromptHintingEnabled ? dictionaryHintPrompt : ""
        // CoreML is automatic if the model files are present
        
        whisper = Whisper(fromFileURL: URL(fileURLWithPath: modelPath), withParams: params)
    }

    /// Unloads the currently cached model instance.
    /// Used when model files are deleted so re-download can warm from disk again.
    func unloadModel() {
        guard whisper != nil else { return }
        whisper = nil
        #if DEBUG
        print("WhisperService: Unloaded model from memory.")
        #endif
    }
    
    private var transcriptionTask: Task<Void, Never>?
    
    func cancelTranscription() {
        transcriptionTask?.cancel()
        transcriptionTask = nil
        #if DEBUG
        print("WhisperService: Transcription cancelled.")
        #endif
    }

    func updateDictionaryHintPrompt(_ prompt: String) {
        let cleanedPrompt = prompt
            .trimmingCharacters(in: .whitespacesAndNewlines)
        dictionaryHintPrompt = cleanedPrompt
        whisper?.params.initialPrompt = isPromptHintingEnabled ? cleanedPrompt : ""
    }
    
    func transcribe(
        audioFrames: [Float],
        useDictionaryHintPrompt: Bool = true,
        enableAutoParagraphs: Bool = true,
        completion: @escaping (String?) -> Void
    ) {
        // Hardening: ensure only one transcription runs at a time
        transcriptionTask?.cancel()
        transcriptionTask = nil
        guard !audioFrames.isEmpty else {
            #if DEBUG
            print("Skipping transcription: audio buffer is empty or silent.")
            #endif
            completion("")
            return
        }
        
        self.isTranscribing = true
        self.lastResultWasLikelyNoSpeech = false
        
        // Ensure model is loaded (if warmup wasn't called/finished)
        if whisper == nil {
            warmup()
        }

        let shouldUseDictionaryHintPrompt = isPromptHintingEnabled && useDictionaryHintPrompt

        if shouldUseDictionaryHintPrompt {
            whisper?.params.initialPrompt = dictionaryHintPrompt
        } else {
            whisper?.params.initialPrompt = ""
            #if DEBUG
            print("WhisperService: Dictionary hint prompt disabled.")
            #endif
        }

        let restoreDictionaryHintPromptIfNeeded = { [weak self] in
            guard let self, !shouldUseDictionaryHintPrompt else { return }
            self.whisper?.params.initialPrompt = self.isPromptHintingEnabled ? self.dictionaryHintPrompt : ""
        }
        
        #if DEBUG
        print("Transcribing \(audioFrames.count) raw frames...")
        #endif
        
        transcriptionTask = Task {
            do {
                let chunkResult = self.paragraphChunker.split(audioFrames)
                #if DEBUG
                let boundaryMs = chunkResult.boundaryFrames.map { Int((Double($0) / 16_000.0) * 1_000.0) }
                print(
                    "WhisperService chunking: chunks=\(chunkResult.chunks.count) " +
                    "boundariesMs=\(boundaryMs) silenceThreshold=\(String(format: "%.5f", chunkResult.silenceThreshold))"
                )
                #endif

                var transcribedSegments: [Segment] = []
                var chunkTexts: [String] = []
                for (chunkIndex, chunk) in chunkResult.chunks.enumerated() {
                    if Task.isCancelled {
                        DispatchQueue.main.async {
                            self.isTranscribing = false
                            restoreDictionaryHintPromptIfNeeded()
                        }
                        return
                    }

                    let chunkFrames = Array(audioFrames[chunk.startFrame..<chunk.endFrame])
                    guard !chunkFrames.isEmpty else { continue }

                    let segments = try await self.transcribeChunkWithLeadingPhraseRetry(
                        chunkFrames: chunkFrames,
                        usedDictionaryHintPrompt: shouldUseDictionaryHintPrompt
                    )
                    #if DEBUG
                    logChunkSegments(segments, chunkIndex: chunkIndex, totalChunks: chunkResult.chunks.count)
                    #endif
                    transcribedSegments.append(contentsOf: segments)
                    let chunkText = segments
                        .map { $0.text }
                        .joined(separator: " ")
                        .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
                        .trimmingCharacters(in: .whitespacesAndNewlines)
                    if !chunkText.isEmpty {
                        chunkTexts.append(chunkText)
                    }
                }
                
                // Check if task was cancelled before proceeding
                if Task.isCancelled {
                    DispatchQueue.main.async {
                        self.isTranscribing = false
                        restoreDictionaryHintPromptIfNeeded()
                    }
                    return
                }
                
                let paragraphSeparator = enableAutoParagraphs ? "\n\n" : " "
                let text = chunkTexts
                    .joined(separator: paragraphSeparator)
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                let hasSegments = !transcribedSegments.isEmpty
                let allSegmentsHighNoSpeech = hasSegments && transcribedSegments.allSatisfy {
                    $0.noSpeechProbability >= self.noSpeechSegmentProbabilityThreshold
                }
                let averageNoSpeechProbability: Float = hasSegments
                    ? transcribedSegments.reduce(0) { $0 + $1.noSpeechProbability } / Float(transcribedSegments.count)
                    : 1.0
                let likelyNoSpeechByDecoder = !hasSegments
                    || allSegmentsHighNoSpeech
                    || averageNoSpeechProbability >= self.noSpeechAverageProbabilityThreshold

                let cleanedText = self.normalizeChunkedOutputWhitespace(text)
                let finalText = likelyNoSpeechByDecoder ? "" : cleanedText
                #if DEBUG
                print(
                    "WhisperService paragraphing: segments=\(transcribedSegments.count) " +
                    "enabled=\(enableAutoParagraphs) " +
                    "hasParagraphBreaks=\(finalText.contains("\n\n"))"
                )
                #endif

                DispatchQueue.main.async {
                    self.isTranscribing = false
                    restoreDictionaryHintPromptIfNeeded()
                    self.lastResultWasLikelyNoSpeech = likelyNoSpeechByDecoder
                    self.transcriptionText = finalText
                    completion(finalText)
                }
            } catch {
                if Task.isCancelled {
                    DispatchQueue.main.async {
                        self.isTranscribing = false
                        restoreDictionaryHintPromptIfNeeded()
                    }
                    return
                }
                
                #if DEBUG
                print("Transcription error: \(error)")
                #endif
                DispatchQueue.main.async {
                    self.isTranscribing = false
                    restoreDictionaryHintPromptIfNeeded()
                    self.lastResultWasLikelyNoSpeech = false
                    completion(nil)
                }
            }
        }
    }
    
    // Legacy support for file-based transcription (can be removed later)
    func transcribe(audioURL: URL, completion: @escaping (String?) -> Void) {
        Task {
            do {
                let audioFrames = try loadAndResample(url: audioURL)
                transcribe(audioFrames: audioFrames, enableAutoParagraphs: true, completion: completion)
            } catch {
                completion(nil)
            }
        }
    }
    
    private func loadAndResample(url: URL) throws -> [Float] {
        let inputFile = try AVAudioFile(forReading: url)
        let inputFormat = inputFile.processingFormat
        
        let outputFormat = AVAudioFormat(commonFormat: .pcmFormatFloat32, sampleRate: 16000, channels: 1, interleaved: false)!
        
        guard let converter = AVAudioConverter(from: inputFormat, to: outputFormat) else {
            throw NSError(domain: "WhisperService", code: 1, userInfo: [NSLocalizedDescriptionKey: "Failed to create converter"])
        }
        
        let ratio = 16000.0 / inputFormat.sampleRate
        let outputCapacity = AVAudioFrameCount(Double(inputFile.length) * ratio) + 1
        
        guard let outputBuffer = AVAudioPCMBuffer(pcmFormat: outputFormat, frameCapacity: outputCapacity) else {
            throw NSError(domain: "WhisperService", code: 2, userInfo: [NSLocalizedDescriptionKey: "Failed to create buffer"])
        }
        
        var error: NSError?
        let inputBlock: AVAudioConverterInputBlock = { inNumPackets, outStatus in
            let inputBuffer = AVAudioPCMBuffer(pcmFormat: inputFormat, frameCapacity: inNumPackets)!
            do {
                try inputFile.read(into: inputBuffer)
                outStatus.pointee = .haveData
                return inputBuffer
            } catch {
                outStatus.pointee = .noDataNow
                return nil
            }
        }
        
        let status = converter.convert(to: outputBuffer, error: &error, withInputFrom: inputBlock)
        
        if status == .error {
            throw error ?? NSError(domain: "WhisperService", code: 3, userInfo: [NSLocalizedDescriptionKey: "Conversion failed"])
        }
        
        guard let floatData = outputBuffer.floatChannelData else { return [] }
        return Array(UnsafeBufferPointer(start: floatData[0], count: Int(outputBuffer.frameLength)))
    }
    
    private func getModelPath() -> String? {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let modelsDir = appSupport
            .appendingPathComponent("KeyVox")
            .appendingPathComponent("Models")
        
        let baseModelURL = modelsDir.appendingPathComponent("ggml-base.bin")
        if FileManager.default.fileExists(atPath: baseModelURL.path) {
            return baseModelURL.path
        }
        
        return nil
    }

    private func normalizeChunkedOutputWhitespace(_ text: String) -> String {
        guard !text.isEmpty else { return text }

        let normalizedLines = text
            .split(separator: "\n", omittingEmptySubsequences: false)
            .map { line in
                String(line)
                    .replacingOccurrences(of: "[\\t ]+", with: " ", options: .regularExpression)
                    .trimmingCharacters(in: .whitespaces)
            }

        return normalizedLines.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func transcribeChunkWithLeadingPhraseRetry(
        chunkFrames: [Float],
        usedDictionaryHintPrompt: Bool
    ) async throws -> [Segment] {
        let primary = try await whisper?.transcribe(audioFrames: chunkFrames) ?? []
        guard shouldRetryLeadingPhraseDecode(
            primary,
            chunkFrames: chunkFrames,
            usedDictionaryHintPrompt: usedDictionaryHintPrompt
        ) else {
            return primary
        }
        guard let whisper else { return primary }

        let params = whisper.params
        let originalPrompt = params.initialPrompt
        let originalSuppressBlank = params.suppress_blank
        let originalLogprobThreshold = params.logprob_thold

        params.initialPrompt = ""
        params.suppress_blank = false
        params.logprob_thold = retryRelaxedLogprobThreshold

        defer {
            params.initialPrompt = originalPrompt
            params.suppress_blank = originalSuppressBlank
            params.logprob_thold = originalLogprobThreshold
        }

        #if DEBUG
        let duration = Double(chunkFrames.count) / 16_000.0
        print(
            "WhisperService retry: reason=leading_short_result " +
            "chunkSeconds=\(String(format: "%.2f", duration)) " +
            "primaryWords=\(wordCount(in: compactSegmentText(primary)))"
        )
        #endif

        let retry = try await whisper.transcribe(audioFrames: chunkFrames)
        let selected = selectPreferredRetry(primary: primary, retry: retry)
        #if DEBUG
        if selected.elementsEqual(retry, by: { $0.text == $1.text && $0.startTime == $1.startTime && $0.endTime == $1.endTime }) {
            print("WhisperService retry: selected=retry")
        } else {
            print("WhisperService retry: selected=primary")
        }
        #endif
        return selected
    }

    private func shouldRetryLeadingPhraseDecode(
        _ primary: [Segment],
        chunkFrames: [Float],
        usedDictionaryHintPrompt: Bool
    ) -> Bool {
        guard usedDictionaryHintPrompt else { return false }
        let duration = Double(chunkFrames.count) / 16_000.0
        guard duration >= suspiciousShortResultMinChunkSeconds else { return false }

        let compactText = compactSegmentText(primary)
        let words = wordCount(in: compactText)
        let isSuspiciousShortResult = words > 0 && words <= suspiciousShortResultMaxWords
        guard isSuspiciousShortResult else { return false }

        let averageNoSpeechProbability: Float
        if primary.isEmpty {
            averageNoSpeechProbability = 1.0
        } else {
            averageNoSpeechProbability = primary.reduce(0) { $0 + $1.noSpeechProbability } / Float(primary.count)
        }
        guard averageNoSpeechProbability <= suspiciousShortResultMaxNoSpeechProbability else { return false }

        return true
    }

    private func selectPreferredRetry(primary: [Segment], retry: [Segment]) -> [Segment] {
        let primaryText = compactSegmentText(primary)
        let retryText = compactSegmentText(retry)

        let primaryWords = wordCount(in: primaryText)
        let retryWords = wordCount(in: retryText)

        if retryWords >= primaryWords + 2 {
            return retry
        }
        if retryWords == primaryWords && retryText.count >= primaryText.count + 12 {
            return retry
        }
        return primary
    }

    private func compactSegmentText(_ segments: [Segment]) -> String {
        segments
            .map { $0.text }
            .joined(separator: " ")
            .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func wordCount(in text: String) -> Int {
        text.split(whereSeparator: \.isWhitespace).count
    }

    #if DEBUG
    private func logChunkSegments(_ segments: [Segment], chunkIndex: Int, totalChunks: Int) {
        guard !segments.isEmpty else {
            print("WhisperService segments: chunk=\(chunkIndex + 1)/\(totalChunks) count=0")
            return
        }
        let rawDebugTextLoggingEnabled = ProcessInfo.processInfo.environment["KVX_DEBUG_LOG_RAW_TEXT"] == "1"

        let segmentSummaries = segments.prefix(3).enumerated().map { index, segment in
            let loggedText: String
            if rawDebugTextLoggingEnabled {
                let compactText = segment.text
                    .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                loggedText = compactText.count > 80 ? String(compactText.prefix(80)) + "…" : compactText
            } else {
                loggedText = "<redacted>"
            }
            return
                "#\(index + 1){start=\(segment.startTime),end=\(segment.endTime),p=\(String(format: "%.3f", segment.noSpeechProbability)),text=\(loggedText)}"
        }.joined(separator: " ")

        print(
            "WhisperService segments: chunk=\(chunkIndex + 1)/\(totalChunks) count=\(segments.count) \(segmentSummaries)"
        )
    }
    #endif
}
