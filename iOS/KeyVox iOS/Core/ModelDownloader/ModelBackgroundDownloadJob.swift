import Foundation

struct ModelBackgroundTaskDescriptor: Equatable, Sendable {
    let modelID: DictationModelID
    let relativePath: String

    var taskDescription: String {
        "\(modelID.rawValue)::\(relativePath)"
    }

    init(modelID: DictationModelID, relativePath: String) {
        self.modelID = modelID
        self.relativePath = relativePath
    }

    init?(taskDescription: String) {
        guard let separatorRange = taskDescription.range(of: "::") else {
            return nil
        }

        let modelIDRawValue = String(taskDescription[..<separatorRange.lowerBound])
        guard let modelID = DictationModelID(rawValue: modelIDRawValue) else {
            return nil
        }

        self.modelID = modelID
        self.relativePath = String(taskDescription[separatorRange.upperBound...])
    }
}

enum ModelBackgroundArtifactPhase: String, Codable, Sendable {
    case pending
    case downloading
    case downloaded
    case failed
}

enum ModelBackgroundFinalizationState: String, Codable, Sendable {
    case awaitingDownloads
    case pending
    case inProgress
    case failed
}

struct ModelBackgroundArtifactState: Codable, Sendable {
    var phase: ModelBackgroundArtifactPhase
    var taskIdentifier: Int?
    var completedBytes: Int64
    var expectedBytes: Int64?
    var errorMessage: String?
    var updatedAt: Date

    init(
        phase: ModelBackgroundArtifactPhase = .pending,
        taskIdentifier: Int? = nil,
        completedBytes: Int64 = 0,
        expectedBytes: Int64? = nil,
        errorMessage: String? = nil,
        updatedAt: Date = .now
    ) {
        self.phase = phase
        self.taskIdentifier = taskIdentifier
        self.completedBytes = completedBytes
        self.expectedBytes = expectedBytes
        self.errorMessage = errorMessage
        self.updatedAt = updatedAt
    }

    var isDownloaded: Bool {
        phase == .downloaded
    }

    var isActive: Bool {
        phase == .downloading
    }
}

struct ModelBackgroundDownloadJob: Codable, Sendable {
    var modelID: DictationModelID
    var artifactStatesByRelativePath: [String: ModelBackgroundArtifactState]
    var finalizationState: ModelBackgroundFinalizationState
    var lastErrorMessage: String?
    var updatedAt: Date

    init(
        modelID: DictationModelID,
        artifactStatesByRelativePath: [String: ModelBackgroundArtifactState]? = nil,
        finalizationState: ModelBackgroundFinalizationState = .awaitingDownloads,
        lastErrorMessage: String? = nil,
        updatedAt: Date = .now
    ) {
        self.modelID = modelID
        if let artifactStatesByRelativePath {
            self.artifactStatesByRelativePath = artifactStatesByRelativePath
        } else {
            self.artifactStatesByRelativePath = Dictionary(
                uniqueKeysWithValues: DictationModelCatalog.descriptor(for: modelID).artifacts.map { artifact in
                    (artifact.relativePath, ModelBackgroundArtifactState())
                }
            )
        }
        self.finalizationState = finalizationState
        self.lastErrorMessage = lastErrorMessage
        self.updatedAt = updatedAt
    }

    mutating func touch() {
        updatedAt = .now
    }

    func artifactState(for relativePath: String) -> ModelBackgroundArtifactState {
        artifactStatesByRelativePath[relativePath] ?? .init()
    }

    mutating func setArtifactState(
        _ state: ModelBackgroundArtifactState,
        for relativePath: String
    ) {
        artifactStatesByRelativePath[relativePath] = state
        touch()
    }

    var downloadProgressFraction: Double {
        let descriptor = DictationModelCatalog.descriptor(for: modelID)
        let expectedBytes = descriptor.artifacts.reduce(into: Int64(0)) { total, artifact in
            let state = artifactState(for: artifact.relativePath)
            total += max(state.expectedBytes ?? artifact.progressTotalBytes, artifact.progressTotalBytes)
        }

        guard expectedBytes > 0 else { return 0 }

        let completedBytes = descriptor.artifacts.reduce(into: Int64(0)) { total, artifact in
            let state = artifactState(for: artifact.relativePath)
            let artifactExpected = max(state.expectedBytes ?? artifact.progressTotalBytes, artifact.progressTotalBytes)
            total += min(state.completedBytes, artifactExpected)
        }

        return min(max(Double(completedBytes) / Double(expectedBytes), 0), 1)
    }

    var hasActiveDownload: Bool {
        artifactStatesByRelativePath.values.contains(where: \.isActive)
    }

    var isReadyForFinalization: Bool {
        let descriptor = DictationModelCatalog.descriptor(for: modelID)
        return descriptor.artifacts.allSatisfy { artifactState(for: $0.relativePath).isDownloaded }
    }
}
