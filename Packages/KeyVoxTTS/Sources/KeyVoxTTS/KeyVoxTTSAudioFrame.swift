import Foundation

public struct KeyVoxTTSAudioFrame: Sendable {
    public let samples: [Float]
    public let frameIndex: Int
    public let chunkIndex: Int
    public let chunkCount: Int
    public let computeMode: KeyVoxTTSComputeMode
    public let isChunkFinalBatch: Bool
    public let chunkDebugID: String
    public let estimatedRemainingSampleCount: Int
    public let chunkGeneratedSampleCount: Int?
    public let chunkGenerationDurationSeconds: Double?

    public init(
        samples: [Float],
        frameIndex: Int,
        chunkIndex: Int,
        chunkCount: Int,
        computeMode: KeyVoxTTSComputeMode,
        isChunkFinalBatch: Bool,
        chunkDebugID: String,
        estimatedRemainingSampleCount: Int,
        chunkGeneratedSampleCount: Int? = nil,
        chunkGenerationDurationSeconds: Double? = nil
    ) {
        self.samples = samples
        self.frameIndex = frameIndex
        self.chunkIndex = chunkIndex
        self.chunkCount = chunkCount
        self.computeMode = computeMode
        self.isChunkFinalBatch = isChunkFinalBatch
        self.chunkDebugID = chunkDebugID
        self.estimatedRemainingSampleCount = estimatedRemainingSampleCount
        self.chunkGeneratedSampleCount = chunkGeneratedSampleCount
        self.chunkGenerationDurationSeconds = chunkGenerationDurationSeconds
    }

    public var sampleCount: Int {
        samples.count
    }
}
