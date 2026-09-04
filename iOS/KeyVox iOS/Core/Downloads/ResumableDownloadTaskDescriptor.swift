import Foundation

struct ResumableDownloadTaskDescriptor: Sendable {
    nonisolated private static let separator = "::"

    let jobID: UUID
    let artifactID: String

    nonisolated var encoded: String {
        let encodedArtifactID = Data(artifactID.utf8).base64EncodedString()
        return jobID.uuidString + Self.separator + encodedArtifactID
    }

    nonisolated init(jobID: UUID, artifactID: String) {
        self.jobID = jobID
        self.artifactID = artifactID
    }

    nonisolated init?(encoded: String) {
        let components = encoded.components(separatedBy: Self.separator)
        guard components.count == 2,
              let jobID = UUID(uuidString: components[0]),
              let artifactData = Data(base64Encoded: components[1]),
              let artifactID = String(data: artifactData, encoding: .utf8) else {
            return nil
        }
        self.jobID = jobID
        self.artifactID = artifactID
    }
}
