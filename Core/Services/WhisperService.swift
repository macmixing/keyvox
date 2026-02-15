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
    
    /// Pre-loads the model into memory to eliminate cold-start latency.
    func warmup() {
        guard whisper == nil else { return }
        guard let modelPath = getModelPath() else { return }
        
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
        params.initialPrompt = dictionaryHintPrompt
        // CoreML is automatic if the model files are present
        
        whisper = Whisper(fromFileURL: URL(fileURLWithPath: modelPath), withParams: params)
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
        whisper?.params.initialPrompt = cleanedPrompt
    }
    
    func transcribe(
        audioFrames: [Float],
        useDictionaryHintPrompt: Bool = true,
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

        if useDictionaryHintPrompt {
            whisper?.params.initialPrompt = dictionaryHintPrompt
        } else {
            whisper?.params.initialPrompt = ""
            #if DEBUG
            print("WhisperService: Suppressing dictionary hint prompt for low-confidence capture.")
            #endif
        }

        let restoreDictionaryHintPromptIfNeeded = { [weak self] in
            guard let self, !useDictionaryHintPrompt else { return }
            self.whisper?.params.initialPrompt = self.dictionaryHintPrompt
        }
        
        #if DEBUG
        print("Transcribing \(audioFrames.count) raw frames...")
        #endif
        
        transcriptionTask = Task {
            do {
                let segments = try await whisper?.transcribe(audioFrames: audioFrames)
                
                // Check if task was cancelled before proceeding
                if Task.isCancelled {
                    DispatchQueue.main.async {
                        self.isTranscribing = false
                        restoreDictionaryHintPromptIfNeeded()
                    }
                    return
                }
                
                let transcribedSegments = segments ?? []
                let text = transcribedSegments.map { $0.text }.joined(separator: " ").trimmingCharacters(in: .whitespacesAndNewlines)
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

                // Collapse multiple spaces into a single space
                let cleanedText = text.replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
                let finalText = likelyNoSpeechByDecoder ? "" : cleanedText

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
                transcribe(audioFrames: audioFrames, completion: completion)
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
}
