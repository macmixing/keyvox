import Foundation
import KeyVoxSpeechRuntime

/// An optional native encoder implementation. The host supplies verified model
/// artifacts and installed runtime locations; Whisper never downloads them.
public struct WhisperEncoderConfiguration: Sendable {
    public let pluginURL: URL
    public let modelURL: URL
    public let runtimeDirectory: URL

    public init(pluginURL: URL, modelURL: URL, runtimeDirectory: URL) {
        self.pluginURL = pluginURL
        self.modelURL = modelURL
        self.runtimeDirectory = runtimeDirectory
    }

    static func configure(context: OpaquePointer, configuration: Self) -> Bool {
        #if canImport(whisper)
        return false
        #else
        guard configuration.pluginURL.isFileURL, configuration.modelURL.isFileURL,
              configuration.runtimeDirectory.isFileURL else { return false }
        return configuration.pluginURL.path.withCString { plugin in
            configuration.modelURL.path.withCString { model in
                configuration.runtimeDirectory.path.withCString { runtime in
                    kv_whisper_configure_encoder(UnsafeMutableRawPointer(context), plugin, model, runtime)
                }
            }
        }
        #endif
    }
}
