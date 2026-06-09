import Foundation

enum DictationModelID: String, CaseIterable, Identifiable, Codable, Sendable {
    case whisperBase = "whisper-base"
    case parakeetTdtV3 = "parakeet-tdt-v3"

    nonisolated var id: String { rawValue }

    nonisolated var installDirectoryName: String {
        switch self {
        case .whisperBase:
            return "whisper"
        case .parakeetTdtV3:
            return "parakeet"
        }
    }

    nonisolated var providerDisplayName: String {
        switch self {
        case .whisperBase:
            return "Whisper"
        case .parakeetTdtV3:
            return "Parakeet"
        }
    }

    nonisolated var provider: AppSettingsStore.ActiveDictationProvider {
        switch self {
        case .whisperBase:
            return .whisper
        case .parakeetTdtV3:
            return .parakeet
        }
    }
}

enum DictationModelInstallLayout: Equatable, Sendable {
    case subdirectory(String)
}

struct DictationModelArtifact: Equatable, Sendable {
    let relativePath: String
    let remoteURL: URL
    let expectedSHA256: String
    let progressTotalBytes: Int64
    let retainedAfterInstall: Bool
}

struct DictationModelDescriptor: Equatable, Sendable {
    let id: DictationModelID
    let displayName: String
    let installLayout: DictationModelInstallLayout
    let artifacts: [DictationModelArtifact]
    let requiredDownloadBytes: Int64
}

enum DictationModelCatalog {
    nonisolated static let manifestFilename = "install-manifest.json"

    nonisolated static func descriptor(for modelID: DictationModelID) -> DictationModelDescriptor {
        switch modelID {
        case .whisperBase:
            return DictationModelDescriptor(
                id: .whisperBase,
                displayName: "Whisper Base",
                installLayout: .subdirectory("whisper"),
                artifacts: [
                    DictationModelArtifact(
                        relativePath: "ggml-base.bin",
                        remoteURL: ModelDownloadURLs.ggmlBase,
                        expectedSHA256: ModelArtifacts.ggmlBaseSHA256,
                        progressTotalBytes: 140_000_000,
                        retainedAfterInstall: true
                    ),
                    DictationModelArtifact(
                        relativePath: "ggml-base-encoder.mlmodelc.zip",
                        remoteURL: ModelDownloadURLs.coreMLZip,
                        expectedSHA256: ModelArtifacts.coreMLZipSHA256,
                        progressTotalBytes: 50_000_000,
                        retainedAfterInstall: false
                    )
                ],
                requiredDownloadBytes: 220_000_000
            )
        case .parakeetTdtV3:
            return DictationModelDescriptor(
                id: .parakeetTdtV3,
                displayName: "Parakeet TDT v3",
                installLayout: .subdirectory("parakeet"),
                artifacts: parakeetArtifacts,
                requiredDownloadBytes: 600_000_000
            )
        }
    }

    nonisolated private static var parakeetArtifacts: [DictationModelArtifact] {
        [
            artifact("config.json", "44136fa355b3678a1146ad16f7e8649e94fb4fc21fe77e8310c060f61caaff8a", 1),
            artifact("parakeet_vocab.json", "7ec60e05f1b24480736ec0eed40900f4626bce1fa9a60fd700ec7e2a59198735", 1),
            artifact("Preprocessor.mlmodelc/analytics/coremldata.bin", "c9beeb989c8d66f8be11df59bc6df277ec76cee404f6865b46243835ef562f6d", 1),
            artifact("Preprocessor.mlmodelc/coremldata.bin", "dbde3f2300842c1fd51ef3ff948a0bcffe65ffd2dca10707f2509f32c1d65b1d", 1),
            artifact("Preprocessor.mlmodelc/metadata.json", "2a98699e22d279dd37fa1d238aeb1c6db1df0d6fad687775324157689d8f3acf", 1),
            artifact("Preprocessor.mlmodelc/model.mil", "4b8518a956450fec57f06c2a21bdffc26973f7f1fa6842fb38fe917f896b6b93", 1),
            artifact("Preprocessor.mlmodelc/weights/weight.bin", "129b76e3aeafa8afa3ea76d995b964b145fe83700d579f6ff42c4c38fa0968ea", 491_072),
            artifact("EncoderInt4.mlmodelc/analytics/coremldata.bin", "c296e0229ab5e32412fda92f8dcf47f0e63f0c34e343c0e2654f6c37649d2d79", 1),
            artifact("EncoderInt4.mlmodelc/coremldata.bin", "3e6539cd5d5f1c3bd5a01921cd94af85eab609d49d47e1436a16faac958754d6", 1),
            artifact("EncoderInt4.mlmodelc/metadata.json", "77cc9bf9b66724b1d8f10d10cc963894136c7f5768746df2967261bd75146423", 1),
            artifact("EncoderInt4.mlmodelc/model.mil", "e01525a428acf1c62ae952f6951c80d8608c1164394eed547fb37c03886510ff", 1),
            artifact("EncoderInt4.mlmodelc/weights/weight.bin", "6fcf5596562948c7482e116bdb3f364279bed970893b86737b67fe89f36367d9", 297_912_320),
            artifact("Decoder.mlmodelc/analytics/coremldata.bin", "4238c4e81ecd0dc94bd7dfbb60f7e2cc824107c1ffe0387b8607b72833dba350", 1),
            artifact("Decoder.mlmodelc/coremldata.bin", "18647af085d87bd8f3121c8a9b4d4564c1ede038dab63d295b4e745cf2d7fb99", 1),
            artifact("Decoder.mlmodelc/metadata.json", "a39e93cd8371b8ded92635c7804fcd0590f0d1dd9415c6d19a0484be073077d9", 1),
            artifact("Decoder.mlmodelc/model.mil", "ef2a0a281695398a62fde86ac269c68f73d5b578d7ed3b31f2ba91a2d1ea1f35", 1),
            artifact("Decoder.mlmodelc/weights/weight.bin", "48adf0f0d47c406c8253d4f7fef967436a39da14f5a65e66d5a4b407be355d41", 23_604_992),
            artifact("JointDecisionv3.mlmodelc/analytics/coremldata.bin", "26def4bf73dd56d29dee21c8ef97cb8969e62f6120ed1adc91e46828e2737b6c", 1),
            artifact("JointDecisionv3.mlmodelc/coremldata.bin", "f5fc08b741400f0088492c9e839418b1e18522f19cba28d361dd030c5f398342", 1),
            artifact("JointDecisionv3.mlmodelc/metadata.json", "d9307211b9a37e0f0ac260c7660b1571a3de25841035cfdf9b58fd40425f890f", 1),
            artifact("JointDecisionv3.mlmodelc/model.mil", "be60732943389a047175111a83f8839f3eb39d4803adafa828a0871b2f39818d", 1),
            artifact("JointDecisionv3.mlmodelc/weights/weight.bin", "4e0e63d840032f7f07ddb1d64446051166281e5491bf22da8a945c41f6eedb3e", 12_642_764),
        ]
    }

    nonisolated private static func artifact(
        _ relativePath: String,
        _ sha256: String,
        _ progressTotalBytes: Int64
    ) -> DictationModelArtifact {
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
            progressTotalBytes: progressTotalBytes,
            retainedAfterInstall: true
        )
    }
}
