import Foundation
import KeyVoxSpeechRuntime

#if canImport(whisper)
/// Limits whisper.cpp's console output to warnings and errors for the whole process, since the
/// live detector runs a detection pass, each logging informational lines, for every window.
enum WhisperRuntimeLogFilter {
    static let install: Void = {
        whisper_log_set({ level, text, _ in
            guard level == GGML_LOG_LEVEL_WARN || level == GGML_LOG_LEVEL_ERROR,
                  let text else {
                return
            }
            fputs(text, stderr)
        }, nil)
    }()
}
#endif
