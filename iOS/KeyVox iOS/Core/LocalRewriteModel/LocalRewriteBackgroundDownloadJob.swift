import Foundation

enum LocalRewriteBackgroundDownloadPhase: String, Codable, Sendable {
    case pending
    case downloading
    case downloaded
    case failed
}

enum LocalRewriteBackgroundFinalizationState: String, Codable, Sendable {
    case awaitingDownload
    case pending
    case inProgress
    case failed
}

struct LocalRewriteBackgroundDownloadJob: Codable, Equatable, Sendable {
    let id: UUID
    let modelID: String
    let artifactFilename: String
    let remoteURL: URL
    let expectedSHA256: String
    let expectedByteCount: Int64
    var phase: LocalRewriteBackgroundDownloadPhase
    var taskIdentifier: Int?
    var completedBytes: Int64
    var expectedBytes: Int64?
    var finalizationState: LocalRewriteBackgroundFinalizationState
    var lastErrorMessage: String?
    var updatedAt: Date

    init(id: UUID = UUID(), descriptor: LocalRewriteModelDescriptor) {
        self.id = id
        self.modelID = descriptor.id
        self.artifactFilename = descriptor.artifact.filename
        self.remoteURL = descriptor.artifact.remoteURL
        self.expectedSHA256 = descriptor.artifact.expectedSHA256
        self.expectedByteCount = descriptor.artifact.progressTotalBytes
        self.phase = .pending
        self.taskIdentifier = nil
        self.completedBytes = 0
        self.expectedBytes = descriptor.artifact.progressTotalBytes
        self.finalizationState = .awaitingDownload
        self.lastErrorMessage = nil
        self.updatedAt = .now
    }

    var downloadProgressFraction: Double {
        let totalBytes = max(expectedBytes ?? expectedByteCount, expectedByteCount)
        guard totalBytes > 0 else { return phase == .downloaded ? 1 : 0 }
        return min(max(Double(min(completedBytes, totalBytes)) / Double(totalBytes), 0), 1)
    }

    var isReadyForFinalization: Bool {
        phase == .downloaded
    }

    func matches(_ descriptor: LocalRewriteModelDescriptor) -> Bool {
        modelID == descriptor.id
            && artifactFilename == descriptor.artifact.filename
            && remoteURL == descriptor.artifact.remoteURL
            && expectedSHA256.lowercased() == descriptor.artifact.expectedSHA256.lowercased()
            && expectedByteCount == descriptor.artifact.progressTotalBytes
    }
}
