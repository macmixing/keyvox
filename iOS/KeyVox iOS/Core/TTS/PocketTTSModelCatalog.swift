import Foundation

struct PocketTTSArtifact: Equatable, Sendable {
    let relativePath: String
    let remoteURL: URL
    let expectedSHA256: String
    let expectedByteCount: Int64
}

struct PocketTTSDescriptor: Equatable, Sendable {
    let displayName: String
    let artifacts: [PocketTTSArtifact]

    var requiredDownloadBytes: Int64 {
        artifacts.reduce(0) { $0 + $1.expectedByteCount }
    }
}

enum PocketTTSModelCatalog {
    static let repositoryID = "FluidInference/pocket-tts-coreml"
    static let displayName = "PocketTTS CoreML"
    private static let revision = "b51c4854305532b182026259092cc53e4b600f49"
    private static let approximateVoiceDownloadBytesByID: [AppSettingsStore.TTSVoice: Int64] = [
        .alba: 19_000_000,
        .azelma: 17_000_000,
        .cosette: 18_000_000,
        .eponine: 18_000_000,
        .fantine: 18_000_000,
        .javert: 19_000_000,
        .jean: 19_000_000,
        .marius: 18_000_000,
    ]

    static func approximateVoiceDownloadBytes(for voice: AppSettingsStore.TTSVoice) -> Int64 {
        approximateVoiceDownloadBytesByID[voice] ?? 18_000_000
    }

    static var sharedModelDescriptor: PocketTTSDescriptor {
        PocketTTSDescriptor(
            displayName: displayName,
            artifacts: [
                sharedArtifact("cond_step.mlmodelc/analytics/coremldata.bin", "8e41425950df48be80e3dfd4cff9dc33b0fcd05b1bc97a3dcaa10bbcc86d8c86", 243),
                sharedArtifact("cond_step.mlmodelc/coremldata.bin", "fa2a2c08fd199a50bb5762f9ea0cdd0e5b38673634062c1c955d5b376cb0bfe3", 1_125),
                sharedArtifact("cond_step.mlmodelc/model.mil", "f7ec2e6bcd293aa5aa05a532441c718ebdf6cbaeb08b657438c0f8a46e3416d6", 193_409),
                sharedArtifact("cond_step.mlmodelc/weights/weight.bin", "6378675f49d0e93b9e0536a455c6e43ccd2ca94f63d5e3ebab79af4412f76741", 266_467_520),
                sharedArtifact("constants_bin/bos_emb.bin", "e66fe9dfbbb7d543ed6271144191112364481e1f8e1507e6ab51f412b5348bd4", 128),
                sharedArtifact("constants_bin/manifest.json", "8d37ae6341e0a1b3d11e5a79168bd0f4e224a8ff8f385187ddd13356121ef19b", 5_641),
                sharedArtifact("constants_bin/mimi_init_state/attn0_cache.bin", "30e14955ebf1352266dc2ff8067e68104607e750abb9d3b36582b8af909fcb58", 1_048_576),
                sharedArtifact("constants_bin/mimi_init_state/attn0_end_offset.bin", "df3f619804a92fdb4057192dc43dd748ea778adc52bc498ce80524c014b81119", 4),
                sharedArtifact("constants_bin/mimi_init_state/attn0_offset.bin", "df3f619804a92fdb4057192dc43dd748ea778adc52bc498ce80524c014b81119", 4),
                sharedArtifact("constants_bin/mimi_init_state/attn1_cache.bin", "30e14955ebf1352266dc2ff8067e68104607e750abb9d3b36582b8af909fcb58", 1_048_576),
                sharedArtifact("constants_bin/mimi_init_state/attn1_end_offset.bin", "df3f619804a92fdb4057192dc43dd748ea778adc52bc498ce80524c014b81119", 4),
                sharedArtifact("constants_bin/mimi_init_state/attn1_offset.bin", "df3f619804a92fdb4057192dc43dd748ea778adc52bc498ce80524c014b81119", 4),
                sharedArtifact("constants_bin/mimi_init_state/conv0_first.bin", "e00e5eb9444182f352323374ef4e08ebcb784725fdd4fd612d7730540b3e0c8c", 4),
                sharedArtifact("constants_bin/mimi_init_state/conv0_prev.bin", "f3cc103136423a57975750907ebc1d367e2985ac6338976d4d5a439f50323f4a", 12_288),
                sharedArtifact("constants_bin/mimi_init_state/conv_final_first.bin", "e00e5eb9444182f352323374ef4e08ebcb784725fdd4fd612d7730540b3e0c8c", 4),
                sharedArtifact("constants_bin/mimi_init_state/conv_final_prev.bin", "076a27c79e5ace2a3d47f9dd2e83e4ff6ea8872b3c2218f66c92b89b55f36560", 512),
                sharedArtifact("constants_bin/mimi_init_state/convtr0_partial.bin", "fd9243e1ba57263ed469c3bdbd7ade6ec5254e7ed924a9f5737fa44749933cc0", 6_144),
                sharedArtifact("constants_bin/mimi_init_state/convtr1_partial.bin", "8ce8ba8e726ee8925e6560d86ac35be1097691d1cfac888e6bd20e804ea9eb15", 2_560),
                sharedArtifact("constants_bin/mimi_init_state/convtr2_partial.bin", "5f70bf18a086007016e948b04aed3b82103a36bea41755b6cddfaf10ace3c6ef", 1_024),
                sharedArtifact("constants_bin/mimi_init_state/res0_conv0_first.bin", "e00e5eb9444182f352323374ef4e08ebcb784725fdd4fd612d7730540b3e0c8c", 4),
                sharedArtifact("constants_bin/mimi_init_state/res0_conv0_prev.bin", "e5a00aa9991ac8a5ee3109844d84a55583bd20572ad3ffcd42792f3c36b183ad", 2_048),
                sharedArtifact("constants_bin/mimi_init_state/res0_conv1_first.bin", "e00e5eb9444182f352323374ef4e08ebcb784725fdd4fd612d7730540b3e0c8c", 4),
                sharedArtifact("constants_bin/mimi_init_state/res0_conv1_prev.bin", "e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855", 0),
                sharedArtifact("constants_bin/mimi_init_state/res1_conv0_first.bin", "e00e5eb9444182f352323374ef4e08ebcb784725fdd4fd612d7730540b3e0c8c", 4),
                sharedArtifact("constants_bin/mimi_init_state/res1_conv0_prev.bin", "5f70bf18a086007016e948b04aed3b82103a36bea41755b6cddfaf10ace3c6ef", 1_024),
                sharedArtifact("constants_bin/mimi_init_state/res1_conv1_first.bin", "e00e5eb9444182f352323374ef4e08ebcb784725fdd4fd612d7730540b3e0c8c", 4),
                sharedArtifact("constants_bin/mimi_init_state/res1_conv1_prev.bin", "e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855", 0),
                sharedArtifact("constants_bin/mimi_init_state/res2_conv0_first.bin", "e00e5eb9444182f352323374ef4e08ebcb784725fdd4fd612d7730540b3e0c8c", 4),
                sharedArtifact("constants_bin/mimi_init_state/res2_conv0_prev.bin", "076a27c79e5ace2a3d47f9dd2e83e4ff6ea8872b3c2218f66c92b89b55f36560", 512),
                sharedArtifact("constants_bin/mimi_init_state/res2_conv1_first.bin", "e00e5eb9444182f352323374ef4e08ebcb784725fdd4fd612d7730540b3e0c8c", 4),
                sharedArtifact("constants_bin/mimi_init_state/res2_conv1_prev.bin", "e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855", 0),
                sharedArtifact("constants_bin/mimi_init_state/upsample_partial.bin", "c35020473aed1b4642cd726cad727b63fff2824ad68cedd7ffb73c7cbd890479", 32_768),
                sharedArtifact("constants_bin/text_embed_table.bin", "08100a5e7ac7a90ade31d38d4ec379309c136b2d9c9fa6709b3d3ffc61d751ce", 16_388_096),
                sharedArtifact("constants_bin/tokenizer.model", "d461765ae179566678c93091c5fa6f2984c31bbe990bf1aa62d92c64d91bc3f6", 59_339),
                sharedArtifact("flow_decoder.mlmodelc/analytics/coremldata.bin", "0149fcce10827c010e495557f287d427f4235a735622edbf09ab5da84c7e1de9", 243),
                sharedArtifact("flow_decoder.mlmodelc/coremldata.bin", "dc3b49a3f933a737b72e23f1fa9d57d9103a9bffe00ca998011d3ee223c10042", 436),
                sharedArtifact("flow_decoder.mlmodelc/model.mil", "d0b1294bda7c66d0d0b6d6ddeb52ea250fe3f3227d8e756aab4955bbeffeec04", 46_123),
                sharedArtifact("flow_decoder.mlmodelc/weights/weight.bin", "9fa32f175b149cbf002d19eb8f72c4421b091ca8bead3c5d2687696966b5d9ca", 39_039_872),
                sharedArtifact("flowlm_step.mlmodelc/analytics/coremldata.bin", "fa1ec42ed08d675b9c5b29875604cfc16e9a0a47b3ad84809680ecfefc35e524", 243),
                sharedArtifact("flowlm_step.mlmodelc/coremldata.bin", "c6f29215ac1a668598e3a98254836cc2f12710f9e39a0a2f782b91128f31b8f9", 1_190),
                sharedArtifact("flowlm_step.mlmodelc/model.mil", "49d553c368ea31720de157267bd34efcdc4cb5530a23ed192e40a8334ff84f6b", 209_706),
                sharedArtifact("flowlm_step.mlmodelc/weights/weight.bin", "7e52a33521c2e98d1399729636733c7371a8f29c365ac66162b9eeaa43c3d1ff", 304_368_384),
                sharedArtifact("mimi_decoder_v2.mlmodelc/analytics/coremldata.bin", "c44d6b8a6c67ea276094eedbc2f5aa8348da4f5f0f65a9b1f51a43b9b9c34d6b", 243),
                sharedArtifact("mimi_decoder_v2.mlmodelc/coremldata.bin", "8cea4e57551a1fc12e67e1e683593bec371b8eda43c84e9bdedbeede04deae78", 1_840),
                sharedArtifact("mimi_decoder_v2.mlmodelc/metadata.json", "36a539e70950ce5e1d9242dc53e115f3f02308caa17fd04df136ae01f6a2f68d", 17_939),
                sharedArtifact("mimi_decoder_v2.mlmodelc/model.mil", "5542d46e8f82087d6720ed33ef9117a17b4d514d38a44a3ec2c53edf1f512e90", 106_347),
                sharedArtifact("mimi_decoder_v2.mlmodelc/weights/weight.bin", "6eafaad7bad7fbe02f32805b5c38590a0b1cf5374e2894f4816f59b87b35f625", 41_244_992),
            ]
        )
    }

    static func voiceDescriptor(for voice: AppSettingsStore.TTSVoice) -> PocketTTSDescriptor {
        PocketTTSDescriptor(
            displayName: voice.displayName,
            artifacts: [
                PocketTTSArtifact(
                    relativePath: "Voices/\(voice.rawValue)/audio_prompt.bin",
                    remoteURL: remoteURL(for: "constants_bin/\(voice.rawValue)_audio_prompt.bin"),
                    expectedSHA256: voiceAudioPromptSHA256(for: voice),
                    expectedByteCount: 512_000
                )
            ]
        )
    }

    private static func voiceAudioPromptSHA256(for voice: AppSettingsStore.TTSVoice) -> String {
        switch voice {
        case .alba:
            return "0b2429b1cce77de299cfe79900a7662b342e58674e659a17892fb08103e389fb"
        case .azelma:
            return "b34007e08c0ca2a7c1e55ca309762376abd67ee9ad6866f31eab3b2a9dc193dd"
        case .cosette:
            return "888d9c8d292b070f607d7dbc7567d27889c91e48ce2228650aa8d38d1dc112b0"
        case .eponine:
            return "ce0be4dede8f54eec21a07ec83af2ef2b673cb60399403b7371ae09f13d4f7b0"
        case .fantine:
            return "85a97436fb3d29fdffe78b0414b66e2e8d0a68d25de662c60b2ec41da8d61dd9"
        case .javert:
            return "5a18376fa3f04245e009a8a3c050ca9611f313c1984d3d46a6c272f97799e6de"
        case .jean:
            return "703bb2b90f981e34af1982b15a4733a0391ab80804abaa8e6e30e5c0dd5ed77a"
        case .marius:
            return "6b14cbb30771b20948da5d0ad3b3adbd6563782eae73e30fe3561d597bef1ef3"
        }
    }

    private static func sharedArtifact(
        _ path: String,
        _ sha256: String,
        _ byteCount: Int64
    ) -> PocketTTSArtifact {
        PocketTTSArtifact(
            relativePath: "Model/\(path)",
            remoteURL: remoteURL(for: path),
            expectedSHA256: sha256,
            expectedByteCount: byteCount
        )
    }

    private static func remoteURL(for path: String) -> URL {
        var components = URLComponents(string: "https://huggingface.co/\(repositoryID)/resolve/\(revision)/\(path)")!
        components.queryItems = [URLQueryItem(name: "download", value: "true")]
        return components.url!
    }
}
