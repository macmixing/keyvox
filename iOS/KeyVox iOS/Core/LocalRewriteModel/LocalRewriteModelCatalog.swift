import Foundation
import KeyVoxVibesAdapters

struct LocalRewriteModelArtifact: Equatable, Sendable {
    let filename: String
    let remoteURL: URL
    let expectedSHA256: String
    let progressTotalBytes: Int64
}

struct LocalRewriteModelDescriptor: Equatable, Sendable {
    let id: String
    let displayName: String
    let sourceRepository: String
    let artifact: LocalRewriteModelArtifact
}

enum LocalRewriteModelCatalog {
    static let manifestFilename = "install-manifest.json"
    static let polishedLoRAFilename = KeyVoxVibesAdapterCatalog.polished.filename
    static let casualLoRAFilename = KeyVoxVibesAdapterCatalog.casual.filename

    static let descriptor = LocalRewriteModelDescriptor(
        id: "qwen2-5-0-5b-instruct",
        displayName: "Qwen2.5-0.5B-Instruct",
        sourceRepository: "Qwen/Qwen2.5-0.5B-Instruct-GGUF",
        artifact: LocalRewriteModelArtifact(
            filename: "qwen2.5-0.5b-instruct-q4_k_m.gguf",
            remoteURL: URL(string: "https://huggingface.co/Qwen/Qwen2.5-0.5B-Instruct-GGUF/resolve/main/qwen2.5-0.5b-instruct-q4_k_m.gguf?download=true")!,
            expectedSHA256: "74a4da8c9fdbcd15bd1f6d01d621410d31c6fc00986f5eb687824e7b93d7a9db",
            progressTotalBytes: 491_400_032
        )
    )
}
