import Foundation

private func phase2DefaultBaseDirectory() throws -> URL {
    let appSupportDirectory = try FileManager.default.url(
        for: .applicationSupportDirectory,
        in: .userDomainMask,
        appropriateFor: nil,
        create: true
    )
    return appSupportDirectory.appendingPathComponent("Phase2Verification", isDirectory: true)
}

@MainActor
final class Phase2CaptureArtifactWriter: Phase2CaptureArtifactWriting {
    private let fileManager: FileManager
    private let baseDirectoryProvider: @MainActor () throws -> URL

    init(
        fileManager: FileManager = .default,
        baseDirectoryProvider: @escaping @MainActor () throws -> URL = phase2DefaultBaseDirectory
    ) {
        self.fileManager = fileManager
        self.baseDirectoryProvider = baseDirectoryProvider
    }

    convenience init(fileManager: FileManager = .default, baseDirectoryURL: URL) {
        self.init(fileManager: fileManager, baseDirectoryProvider: { baseDirectoryURL })
    }

    func writeLatestCapture(_ request: Phase2CaptureWriteRequest) async throws -> Phase2CaptureArtifact {
        let baseDirectoryURL = try baseDirectoryProvider()
        try fileManager.createDirectory(at: baseDirectoryURL, withIntermediateDirectories: true)

        let snapshotURL = baseDirectoryURL.appendingPathComponent("latest-snapshot.wav")
        let transcriptionInputURL = baseDirectoryURL.appendingPathComponent("latest-transcription-input.wav")
        let metadataURL = baseDirectoryURL.appendingPathComponent("latest-metadata.json")

        try Self.writeWAV(samples: request.snapshotFrames, sampleRate: request.sampleRate, to: snapshotURL)

        let finalTranscriptionInputURL: URL?
        if request.outputFrames.isEmpty {
            if fileManager.fileExists(atPath: transcriptionInputURL.path) {
                try fileManager.removeItem(at: transcriptionInputURL)
            }
            finalTranscriptionInputURL = nil
        } else {
            try Self.writeWAV(samples: request.outputFrames, sampleRate: request.sampleRate, to: transcriptionInputURL)
            finalTranscriptionInputURL = transcriptionInputURL
        }

        let artifact = Phase2CaptureArtifact(
            capturedAt: request.capturedAt,
            sampleRate: request.sampleRate,
            snapshotFrameCount: request.snapshotFrames.count,
            outputFrameCount: request.outputFrames.count,
            captureDuration: request.captureDuration,
            hadActiveSignal: request.hadActiveSignal,
            wasAbsoluteSilence: request.wasAbsoluteSilence,
            wasLikelySilence: request.wasLikelySilence,
            wasLongTrueSilence: request.wasLongTrueSilence,
            maxActiveSignalRunDuration: request.maxActiveSignalRunDuration,
            currentCaptureDeviceName: request.currentCaptureDeviceName,
            snapshotWAVURL: snapshotURL,
            transcriptionInputWAVURL: finalTranscriptionInputURL,
            metadataURL: metadataURL
        )

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        let metadata = try encoder.encode(artifact)
        try metadata.write(to: metadataURL, options: .atomic)

        return artifact
    }
    private static func writeWAV(samples: [Float], sampleRate: Double, to url: URL) throws {
        let pcmSamples = samples.map(Self.pcm16Sample(from:))
        let byteRate = UInt32(Int(sampleRate) * MemoryLayout<Int16>.size)
        let blockAlign = UInt16(MemoryLayout<Int16>.size)
        let dataChunkSize = UInt32(pcmSamples.count * MemoryLayout<Int16>.size)
        let riffChunkSize = UInt32(36) + dataChunkSize

        var data = Data()
        data.append(contentsOf: Array("RIFF".utf8))
        data.append(littleEndian: riffChunkSize)
        data.append(contentsOf: Array("WAVE".utf8))
        data.append(contentsOf: Array("fmt ".utf8))
        data.append(littleEndian: UInt32(16))
        data.append(littleEndian: UInt16(1))
        data.append(littleEndian: UInt16(1))
        data.append(littleEndian: UInt32(Int(sampleRate)))
        data.append(littleEndian: byteRate)
        data.append(littleEndian: blockAlign)
        data.append(littleEndian: UInt16(16))
        data.append(contentsOf: Array("data".utf8))
        data.append(littleEndian: dataChunkSize)

        for sample in pcmSamples {
            data.append(littleEndian: UInt16(bitPattern: sample))
        }

        try data.write(to: url, options: .atomic)
    }

    private static func pcm16Sample(from sample: Float) -> Int16 {
        let clamped = min(max(sample, -1.0), 1.0)
        let scaled = (clamped * Float(Int16.max)).rounded()
        return Int16(scaled)
    }
}

private extension Data {
    nonisolated mutating func append<T: FixedWidthInteger>(littleEndian value: T) {
        var littleEndianValue = value.littleEndian
        Swift.withUnsafeBytes(of: &littleEndianValue) { rawBytes in
            append(contentsOf: rawBytes)
        }
    }
}
