import Foundation

struct TTSReplayCacheEntry: Codable, Equatable {
    let request: KeyVoxTTSRequest
    let sampleCount: Int
    let pausedSampleOffset: Int?
}

struct TTSReplayCacheSnapshot: Equatable {
    let request: KeyVoxTTSRequest
    let samples: [Float]
    let pausedSampleOffset: Int?
}

struct TTSReplayCache {
    private let fileManager: FileManager
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    init(fileManager: FileManager = .default) {
        self.fileManager = fileManager
    }

    func load() -> TTSReplayCacheSnapshot? {
        guard let metadataURL = SharedPaths.lastTTSReplayMetadataURL(fileManager: fileManager),
              let audioURL = SharedPaths.lastTTSReplayAudioURL(fileManager: fileManager),
              let metadataData = try? Data(contentsOf: metadataURL),
              let entry = try? decoder.decode(TTSReplayCacheEntry.self, from: metadataData),
              let audioData = try? Data(contentsOf: audioURL) else {
            return nil
        }

        guard entry.sampleCount > 0,
              entry.sampleCount <= Int.max / MemoryLayout<Float>.stride else {
            return nil
        }
        
        let expectedByteCount = entry.sampleCount * MemoryLayout<Float>.stride
        guard audioData.count == expectedByteCount else {
            return nil
        }

        let samples: [Float] = audioData.withUnsafeBytes { rawBuffer in
            let floatBuffer = rawBuffer.bindMemory(to: Float.self)
            return Array(floatBuffer)
        }

        guard samples.count == entry.sampleCount else {
            return nil
        }

        return TTSReplayCacheSnapshot(
            request: entry.request,
            samples: samples,
            pausedSampleOffset: entry.pausedSampleOffset
        )
    }

    func save(request: KeyVoxTTSRequest, samples: [Float], pausedSampleOffset: Int? = nil) {
        guard let metadataURL = SharedPaths.lastTTSReplayMetadataURL(fileManager: fileManager),
              let audioURL = SharedPaths.lastTTSReplayAudioURL(fileManager: fileManager) else {
            return
        }

        let directoryURL = metadataURL.deletingLastPathComponent()
        try? fileManager.createDirectory(
            at: directoryURL,
            withIntermediateDirectories: true,
            attributes: nil
        )

        let entry = TTSReplayCacheEntry(
            request: request,
            sampleCount: samples.count,
            pausedSampleOffset: pausedSampleOffset
        )
        guard let metadataData = try? encoder.encode(entry) else {
            return
        }

        let audioData = samples.withUnsafeBufferPointer { bufferPointer in
            Data(buffer: bufferPointer)
        }

        let metadataTempURL = metadataURL.appendingPathExtension("tmp")
        let audioTempURL = audioURL.appendingPathExtension("tmp")
        
        do {
            try metadataData.write(to: metadataTempURL, options: .atomic)
            try audioData.write(to: audioTempURL, options: .atomic)
            
            try? fileManager.removeItem(at: metadataURL)
            try? fileManager.removeItem(at: audioURL)
            
            try fileManager.moveItem(at: metadataTempURL, to: metadataURL)
            try fileManager.moveItem(at: audioTempURL, to: audioURL)
        } catch {
            try? fileManager.removeItem(at: metadataTempURL)
            try? fileManager.removeItem(at: audioTempURL)
        }
    }

    func updatePauseState(
        request: KeyVoxTTSRequest,
        sampleCount: Int,
        pausedSampleOffset: Int?
    ) {
        guard let metadataURL = SharedPaths.lastTTSReplayMetadataURL(fileManager: fileManager) else {
            return
        }

        let directoryURL = metadataURL.deletingLastPathComponent()
        try? fileManager.createDirectory(
            at: directoryURL,
            withIntermediateDirectories: true,
            attributes: nil
        )

        let entry = TTSReplayCacheEntry(
            request: request,
            sampleCount: sampleCount,
            pausedSampleOffset: pausedSampleOffset
        )
        guard let metadataData = try? encoder.encode(entry) else {
            return
        }

        try? metadataData.write(to: metadataURL, options: .atomic)
    }

    func clear() {
        if let metadataURL = SharedPaths.lastTTSReplayMetadataURL(fileManager: fileManager) {
            try? fileManager.removeItem(at: metadataURL)
        }
        if let audioURL = SharedPaths.lastTTSReplayAudioURL(fileManager: fileManager) {
            try? fileManager.removeItem(at: audioURL)
        }
    }
}
