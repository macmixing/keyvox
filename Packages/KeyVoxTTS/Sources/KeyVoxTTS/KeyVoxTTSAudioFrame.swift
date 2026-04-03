import Foundation

public struct KeyVoxTTSAudioFrame: Sendable {
    public let samples: [Float]
    public let frameIndex: Int
    public let chunkIndex: Int
    public let chunkCount: Int
    public let isChunkFinalBatch: Bool

    public init(
        samples: [Float],
        frameIndex: Int,
        chunkIndex: Int,
        chunkCount: Int,
        isChunkFinalBatch: Bool
    ) {
        self.samples = samples
        self.frameIndex = frameIndex
        self.chunkIndex = chunkIndex
        self.chunkCount = chunkCount
        self.isChunkFinalBatch = isChunkFinalBatch
    }

    public var sampleCount: Int {
        samples.count
    }
}
