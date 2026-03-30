import Foundation

enum DictationModelID: String, CaseIterable, Identifiable {
    case whisperBase = "whisper-base"
    case parakeetTdtV3 = "parakeet-tdt-v3"

    var id: String { rawValue }
}

enum DictationModelInstallLayout: Equatable {
    case legacyWhisperBase
    case subdirectory(String)
}

struct DictationModelArtifact: Equatable {
    let relativePath: String
    let remoteURL: URL
    let expectedSHA256: String
    let progressTotalBytes: Int64
}

struct DictationModelDescriptor: Equatable {
    let id: DictationModelID
    let displayName: String
    let installLayout: DictationModelInstallLayout
    let artifacts: [DictationModelArtifact]
    let requiredDownloadBytes: Int64
    let manifestFilename: String?
}

struct DictationModelInstallState: Equatable {
    var isReady: Bool = false
    var isDownloading: Bool = false
    var progress: Double = 0
    var errorMessage: String?
}

enum DictationModelCatalog {
    static let manifestFilename = "install-manifest.json"

    static func descriptor(for modelID: DictationModelID) -> DictationModelDescriptor {
        switch modelID {
        case .whisperBase:
            return DictationModelDescriptor(
                id: .whisperBase,
                displayName: "Whisper Base",
                installLayout: .legacyWhisperBase,
                artifacts: [
                    DictationModelArtifact(
                        relativePath: "ggml-base.bin",
                        remoteURL: URL(string: "https://huggingface.co/ggerganov/whisper.cpp/resolve/main/ggml-base.bin")!,
                        expectedSHA256: "",
                        progressTotalBytes: 140_000_000
                    ),
                    DictationModelArtifact(
                        relativePath: "ggml-base-encoder.mlmodelc.zip",
                        remoteURL: URL(string: "https://huggingface.co/ggerganov/whisper.cpp/resolve/main/ggml-base-encoder.mlmodelc.zip")!,
                        expectedSHA256: "",
                        progressTotalBytes: 50_000_000
                    )
                ],
                requiredDownloadBytes: 220_000_000,
                manifestFilename: nil
            )
        case .parakeetTdtV3:
            return DictationModelDescriptor(
                id: .parakeetTdtV3,
                displayName: "Parakeet TDT v3",
                installLayout: .subdirectory("parakeet"),
                artifacts: parakeetArtifacts,
                requiredDownloadBytes: 600_000_000,
                manifestFilename: manifestFilename
            )
        }
    }

    private static var parakeetArtifacts: [DictationModelArtifact] {
        [
            artifact("config.json", "44136fa355b3678a1146ad16f7e8649e94fb4fc21fe77e8310c060f61caaff8a", 1),
            artifact("parakeet_vocab.json", "7ec60e05f1b24480736ec0eed40900f4626bce1fa9a60fd700ec7e2a59198735", 1),
            artifact("Preprocessor.mlmodelc/analytics/coremldata.bin", "c9beeb989c8d66f8be11df59bc6df277ec76cee404f6865b46243835ef562f6d", 1),
            artifact("Preprocessor.mlmodelc/coremldata.bin", "dbde3f2300842c1fd51ef3ff948a0bcffe65ffd2dca10707f2509f32c1d65b1d", 1),
            artifact("Preprocessor.mlmodelc/metadata.json", "2a98699e22d279dd37fa1d238aeb1c6db1df0d6fad687775324157689d8f3acf", 1),
            artifact("Preprocessor.mlmodelc/model.mil", "4b8518a956450fec57f06c2a21bdffc26973f7f1fa6842fb38fe917f896b6b93", 1),
            artifact("Preprocessor.mlmodelc/weights/weight.bin", "129b76e3aeafa8afa3ea76d995b964b145fe83700d579f6ff42c4c38fa0968ea", 491_072),
            artifact("Encoder.mlmodelc/analytics/coremldata.bin", "42e638870d73f26b332918a3496ce36793fbb413a81cbd3d16ba01328637a105", 1),
            artifact("Encoder.mlmodelc/coremldata.bin", "d48034a167a82e88fc3df64f60af963ab3983538271175b8319e7d5720a0fb86", 1),
            artifact("Encoder.mlmodelc/metadata.json", "da24da9cca943fb29d7fa8e376d57fca7cb3aa08ca51b956b0b0e56813f087e9", 1),
            artifact("Encoder.mlmodelc/model.mil", "ed7b19156ca29fa7dfd6891deb9fda4b0e8893f68597c985d135736546a43808", 1),
            artifact("Encoder.mlmodelc/weights/weight.bin", "e2020f323703477a5b21d7c2d282c403e371afb5962e79877e3033e73ba6f421", 445_187_200),
            artifact("Decoder.mlmodelc/analytics/coremldata.bin", "4238c4e81ecd0dc94bd7dfbb60f7e2cc824107c1ffe0387b8607b72833dba350", 1),
            artifact("Decoder.mlmodelc/coremldata.bin", "18647af085d87bd8f3121c8a9b4d4564c1ede038dab63d295b4e745cf2d7fb99", 1),
            artifact("Decoder.mlmodelc/metadata.json", "a39e93cd8371b8ded92635c7804fcd0590f0d1dd9415c6d19a0484be073077d9", 1),
            artifact("Decoder.mlmodelc/model.mil", "ef2a0a281695398a62fde86ac269c68f73d5b578d7ed3b31f2ba91a2d1ea1f35", 1),
            artifact("Decoder.mlmodelc/weights/weight.bin", "48adf0f0d47c406c8253d4f7fef967436a39da14f5a65e66d5a4b407be355d41", 23_604_992),
            artifact("JointDecision.mlmodelc/analytics/coremldata.bin", "bc69ef031ed427e888b1f3889d13eb373655edd5ac9927de20b5dae281b636b7", 1),
            artifact("JointDecision.mlmodelc/coremldata.bin", "f56ded0404498e666ffcd84dda0c393924fc3581345ad03e41429ff560cb97b6", 1),
            artifact("JointDecision.mlmodelc/metadata.json", "3044edab5e4ee331d37cef7100074653c944a0e58184ab618aab183a0e0707bc", 1),
            artifact("JointDecision.mlmodelc/model.mil", "2cb084d7e0dc86ad3ddaa53a9631cdd5d97f19839218845b0e65ca065a4d1a5e", 1),
            artifact("JointDecision.mlmodelc/weights/weight.bin", "4e0e63d840032f7f07ddb1d64446051166281e5491bf22da8a945c41f6eedb3e", 12_642_764),
        ]
    }

    private static func artifact(_ relativePath: String, _ sha256: String, _ progressTotalBytes: Int64) -> DictationModelArtifact {
        var url = URL(string: "https://huggingface.co/FluidInference/parakeet-tdt-0.6b-v3-coreml/resolve/main")!
        for component in relativePath.split(separator: "/") {
            url.appendPathComponent(String(component), isDirectory: false)
        }

        var components = URLComponents(url: url, resolvingAgainstBaseURL: false)!
        components.queryItems = [URLQueryItem(name: "download", value: "true")]

        return DictationModelArtifact(
            relativePath: relativePath,
            remoteURL: components.url!,
            expectedSHA256: sha256,
            progressTotalBytes: progressTotalBytes
        )
    }
}
