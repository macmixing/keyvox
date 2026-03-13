import Foundation

enum iOSModelBackgroundArtifactKind: String, Codable, CaseIterable, Sendable {
    case ggml
    case coreMLZip

    var taskDescription: String {
        rawValue
    }

    var downloadURL: URL {
        switch self {
        case .ggml:
            return iOSModelDownloadURLs.ggmlBase
        case .coreMLZip:
            return iOSModelDownloadURLs.coreMLZip
        }
    }
}

enum iOSModelBackgroundArtifactPhase: String, Codable, Sendable {
    case pending
    case downloading
    case downloaded
    case failed
}

enum iOSModelBackgroundFinalizationState: String, Codable, Sendable {
    case awaitingDownloads
    case pending
    case inProgress
    case failed
}

struct iOSModelBackgroundArtifactState: Codable, Sendable {
    var phase: iOSModelBackgroundArtifactPhase
    var taskIdentifier: Int?
    var completedBytes: Int64
    var expectedBytes: Int64?
    var errorMessage: String?
    var updatedAt: Date

    init(
        phase: iOSModelBackgroundArtifactPhase = .pending,
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

struct iOSModelBackgroundDownloadJob: Codable, Sendable {
    var ggml: iOSModelBackgroundArtifactState
    var coreMLZip: iOSModelBackgroundArtifactState
    var finalizationState: iOSModelBackgroundFinalizationState
    var lastErrorMessage: String?
    var updatedAt: Date

    init(
        ggml: iOSModelBackgroundArtifactState = .init(),
        coreMLZip: iOSModelBackgroundArtifactState = .init(),
        finalizationState: iOSModelBackgroundFinalizationState = .awaitingDownloads,
        lastErrorMessage: String? = nil,
        updatedAt: Date = .now
    ) {
        self.ggml = ggml
        self.coreMLZip = coreMLZip
        self.finalizationState = finalizationState
        self.lastErrorMessage = lastErrorMessage
        self.updatedAt = updatedAt
    }

    mutating func touch() {
        updatedAt = .now
    }

    func artifactState(for kind: iOSModelBackgroundArtifactKind) -> iOSModelBackgroundArtifactState {
        switch kind {
        case .ggml:
            return ggml
        case .coreMLZip:
            return coreMLZip
        }
    }

    mutating func setArtifactState(
        _ state: iOSModelBackgroundArtifactState,
        for kind: iOSModelBackgroundArtifactKind
    ) {
        switch kind {
        case .ggml:
            ggml = state
        case .coreMLZip:
            coreMLZip = state
        }
        touch()
    }

    var downloadProgressFraction: Double {
        let ggmlCompleted = min(ggml.completedBytes, ggml.expectedBytes ?? ggml.completedBytes)
        let coreMLCompleted = min(coreMLZip.completedBytes, coreMLZip.expectedBytes ?? coreMLZip.completedBytes)
        let knownExpected = (ggml.expectedBytes ?? 0) + (coreMLZip.expectedBytes ?? 0)
        if knownExpected > 0 {
            let totalCompleted = ggmlCompleted + coreMLCompleted
            return min(max(Double(totalCompleted) / Double(knownExpected), 0), 1)
        }

        let ggmlFallback = ggml.isDownloaded ? 1.0 : 0.0
        let coreMLFallback = coreMLZip.isDownloaded ? 1.0 : 0.0
        return (ggmlFallback + coreMLFallback) / 2
    }

    var hasActiveDownload: Bool {
        ggml.isActive || coreMLZip.isActive
    }

    var isReadyForFinalization: Bool {
        ggml.isDownloaded && coreMLZip.isDownloaded
    }
}
