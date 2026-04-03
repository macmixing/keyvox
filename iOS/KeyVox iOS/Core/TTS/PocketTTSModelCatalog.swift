import Foundation

struct PocketTTSArtifact: Equatable, Sendable {
    let relativePath: String
    let remoteURL: URL
    let expectedByteCount: Int64
}

struct PocketTTSDescriptor: Equatable, Sendable {
    let displayName: String
    let artifacts: [PocketTTSArtifact]

    var requiredDownloadBytes: Int64 {
        artifacts.reduce(0) { $0 + $1.expectedByteCount }
    }
}

private struct PocketTTSRemoteTreeEntry: Decodable, Sendable {
    let type: String
    let size: Int64
    let path: String
}

enum PocketTTSModelCatalog {
    static let repositoryID = "FluidInference/pocket-tts-coreml"
    static let displayName = "PocketTTS CoreML"

    private static let modelDirectories = [
        "cond_step.mlmodelc",
        "flowlm_step.mlmodelc",
        "flow_decoder.mlmodelc",
        "mimi_decoder_v2.mlmodelc",
    ]

    private static let generalConstantFilenames: Set<String> = [
        "bos_emb.bin",
        "manifest.json",
        "text_embed_table.bin",
        "tokenizer.model",
    ]

    private static let supportedVoiceIDs: Set<String> = [
        AppSettingsStore.TTSVoice.azelma.rawValue,
        AppSettingsStore.TTSVoice.javert.rawValue,
    ]

    static func fetchDescriptor(session: URLSession = .shared) async throws -> PocketTTSDescriptor {
        var artifacts: [PocketTTSArtifact] = []
        log("Fetching PocketTTS descriptor from \(repositoryID).")

        for directory in modelDirectories {
            let entries = try await fetchTreeEntries(
                for: directory,
                recursive: true,
                session: session
            )
            log("Fetched \(entries.count) entries for model directory \(directory).")

            let directoryArtifacts = entries
                .filter { $0.type == "file" }
                .filter { entry in
                    directory == "mimi_decoder_v2.mlmodelc"
                        ? !entry.path.contains("/mimi_decoder.mlmodelc/")
                        : true
                }
                .map { entry in
                    PocketTTSArtifact(
                        relativePath: "Model/\(entry.path)",
                        remoteURL: remoteURL(for: entry.path),
                        expectedByteCount: entry.size
                    )
                }
            artifacts.append(contentsOf: directoryArtifacts)
        }

        let constantsEntries = try await fetchTreeEntries(
            for: "constants_bin",
            recursive: true,
            session: session
        )
        log("Fetched \(constantsEntries.count) entries for constants_bin.")

        for entry in constantsEntries where entry.type == "file" {
            let path = entry.path
            let filename = URL(fileURLWithPath: path).lastPathComponent

            if path.hasPrefix("constants_bin/mimi_init_state/") || generalConstantFilenames.contains(filename) {
                artifacts.append(
                    PocketTTSArtifact(
                        relativePath: "Model/\(path)",
                        remoteURL: remoteURL(for: path),
                        expectedByteCount: entry.size
                    )
                )
                continue
            }

            if filename.hasSuffix("_audio_prompt.bin") {
                let voiceID = filename.replacingOccurrences(of: "_audio_prompt.bin", with: "")
                guard supportedVoiceIDs.contains(voiceID) else { continue }

                artifacts.append(
                    PocketTTSArtifact(
                        relativePath: "Voices/\(voiceID)/audio_prompt.bin",
                        remoteURL: remoteURL(for: path),
                        expectedByteCount: entry.size
                    )
                )
            }
        }

        return PocketTTSDescriptor(
            displayName: displayName,
            artifacts: artifacts.sorted { $0.relativePath < $1.relativePath }
        )
    }

    private static func fetchTreeEntries(
        for path: String,
        recursive: Bool,
        session: URLSession
    ) async throws -> [PocketTTSRemoteTreeEntry] {
        var components = URLComponents(string: "https://huggingface.co/api/models/\(repositoryID)/tree/main/\(path)")!
        components.queryItems = [
            URLQueryItem(name: "recursive", value: recursive ? "1" : "0")
        ]

        let (data, response) = try await session.data(from: components.url!)
        guard let httpResponse = response as? HTTPURLResponse,
              200 ..< 300 ~= httpResponse.statusCode else {
            log("Tree fetch failed for \(path).")
            throw NSError(
                domain: "PocketTTSModelCatalog",
                code: 1,
                userInfo: [NSLocalizedDescriptionKey: "Failed to fetch PocketTTS asset metadata."]
            )
        }
        log("Tree fetch succeeded for \(path) with status \(httpResponse.statusCode).")

        return try JSONDecoder().decode([PocketTTSRemoteTreeEntry].self, from: data)
    }

    private static func remoteURL(for path: String) -> URL {
        var components = URLComponents(string: "https://huggingface.co/\(repositoryID)/resolve/main/\(path)")!
        components.queryItems = [URLQueryItem(name: "download", value: "true")]
        return components.url!
    }

    private static func log(_ message: String) {
        NSLog("[PocketTTSModelCatalog] %@", message)
    }
}
