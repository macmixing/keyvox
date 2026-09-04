import Foundation

struct PocketTTSBackgroundArtifact: Codable, Equatable, Sendable {
    let relativePath: String
    let remoteURL: URL
    let expectedByteCount: Int64
}

enum PocketTTSBackgroundArtifactPhase: String, Codable, Sendable {
    case pending
    case downloading
    case downloaded
    case failed
}

struct PocketTTSBackgroundArtifactState: Codable, Equatable, Sendable {
    var phase: PocketTTSBackgroundArtifactPhase = .pending
    var taskIdentifier: Int?
    var completedBytes: Int64 = 0
    var expectedBytes: Int64?
    var retryNotBefore: Date?
    var errorMessage: String?
    var updatedAt: Date = .now
}

enum PocketTTSBackgroundFinalizationState: String, Codable, Sendable {
    case awaitingDownloads
    case pending
    case inProgress
    case failed
}

struct PocketTTSBackgroundDownloadJob: Codable, Equatable, Sendable {
    let id: UUID
    let target: PocketTTSInstallTarget
    let artifacts: [PocketTTSBackgroundArtifact]
    var artifactStatesByRelativePath: [String: PocketTTSBackgroundArtifactState]
    var queuedVoiceAfterSharedModel: AppSettingsStore.TTSVoice?
    var finalizationState: PocketTTSBackgroundFinalizationState
    var lastErrorMessage: String?
    var updatedAt: Date

    init(
        id: UUID = UUID(),
        target: PocketTTSInstallTarget,
        descriptor: PocketTTSDescriptor,
        queuedVoiceAfterSharedModel: AppSettingsStore.TTSVoice? = nil
    ) {
        self.id = id
        self.target = target
        self.artifacts = descriptor.artifacts.map {
            PocketTTSBackgroundArtifact(
                relativePath: $0.relativePath,
                remoteURL: $0.remoteURL,
                expectedByteCount: $0.expectedByteCount
            )
        }
        self.artifactStatesByRelativePath = Dictionary(
            uniqueKeysWithValues: descriptor.artifacts.map {
                ($0.relativePath, PocketTTSBackgroundArtifactState(expectedBytes: $0.expectedByteCount))
            }
        )
        self.queuedVoiceAfterSharedModel = queuedVoiceAfterSharedModel
        self.finalizationState = .awaitingDownloads
        self.lastErrorMessage = nil
        self.updatedAt = .now
    }

    mutating func setArtifactState(
        _ state: PocketTTSBackgroundArtifactState,
        for relativePath: String
    ) {
        artifactStatesByRelativePath[relativePath] = state
        updatedAt = .now
    }

    func artifactState(for relativePath: String) -> PocketTTSBackgroundArtifactState {
        artifactStatesByRelativePath[relativePath] ?? PocketTTSBackgroundArtifactState()
    }

    var downloadProgressFraction: Double {
        let expectedBytes = artifacts.reduce(into: Int64(0)) { total, artifact in
            let state = artifactState(for: artifact.relativePath)
            total += max(state.expectedBytes ?? artifact.expectedByteCount, artifact.expectedByteCount)
        }
        guard expectedBytes > 0 else { return isReadyForFinalization ? 1 : 0 }

        let completedBytes = artifacts.reduce(into: Int64(0)) { total, artifact in
            let state = artifactState(for: artifact.relativePath)
            let expected = max(state.expectedBytes ?? artifact.expectedByteCount, artifact.expectedByteCount)
            total += min(state.completedBytes, expected)
        }
        return min(max(Double(completedBytes) / Double(expectedBytes), 0), 1)
    }

    var isReadyForFinalization: Bool {
        artifacts.allSatisfy { artifactState(for: $0.relativePath).phase == .downloaded }
    }
}

extension PocketTTSInstallTarget: Codable, Sendable {
    private enum CodingKeys: String, CodingKey {
        case kind
        case voice
    }

    private enum Kind: String, Codable {
        case sharedModel
        case voice
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        switch try container.decode(Kind.self, forKey: .kind) {
        case .sharedModel:
            self = .sharedModel
        case .voice:
            self = .voice(try container.decode(AppSettingsStore.TTSVoice.self, forKey: .voice))
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .sharedModel:
            try container.encode(Kind.sharedModel, forKey: .kind)
        case .voice(let voice):
            try container.encode(Kind.voice, forKey: .kind)
            try container.encode(voice, forKey: .voice)
        }
    }
}
