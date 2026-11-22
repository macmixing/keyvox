import Foundation
import KeyVoxStyleRewrite

@MainActor
final class KeyboardLocalStyleRewriteTextTransformer: DictationTextTransforming {
    private enum ResponseWait {
        static let timeout: TimeInterval = 30
        static let pollIntervalNanoseconds: UInt64 = 50_000_000
    }

    private let audioUnitClient: KeyboardTranscriptionAUClient
    private let isAppSessionWarm: () -> Bool

    init(
        audioUnitClient: KeyboardTranscriptionAUClient,
        isAppSessionWarm: @escaping () -> Bool = KeyVoxIPCBridge.isSessionWarm
    ) {
        self.audioUnitClient = audioUnitClient
        self.isAppSessionWarm = isAppSessionWarm
    }

    func prewarm(request: TextTransformRequest) {}

    func transform(_ request: TextTransformRequest) async -> TextTransformResult {
        let start = Date()
        let ipcRequest = KeyVoxStyleRewriteIPCRequest(
            id: UUID(),
            styleIdentifier: request.styleIdentifier,
            baseText: request.baseText,
            languageCode: request.languageCode,
            createdAt: Date()
        )

        do {
            let (response, processingMode) = try await response(to: ipcRequest)

            if let text = response.text,
               text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false {
                return TextTransformResult(
                    originalText: request.baseText,
                    finalText: text,
                    styleIdentifier: request.styleIdentifier,
                    duration: response.duration,
                    chunkCount: response.chunkCount,
                    applied: response.applied,
                    chunkTimings: [],
                    errors: response.errorMessage.map {
                        [TextTransformErrorSummary(chunkIndex: nil, message: $0, errorCode: .generationFailed)]
                    } ?? [],
                    processingMode: processingMode
                )
            }

            return TextTransformResult.fallback(
                request: request,
                duration: Date().timeIntervalSince(start),
                errors: [
                    TextTransformErrorSummary(
                        chunkIndex: nil,
                        message: response.errorMessage ?? "emptyResponse",
                        errorCode: .generationFailed
                    )
                ]
            )
        } catch {
            return TextTransformResult.fallback(
                request: request,
                duration: Date().timeIntervalSince(start),
                errors: [
                    TextTransformErrorSummary(
                        chunkIndex: nil,
                        message: String(describing: error),
                        errorCode: .generationFailed
                    )
                ]
            )
        }
    }

    func releasePrewarmSession(reason: String) {}

    /// The containing app answers while its session is running; otherwise the Transcription AU
    /// extension does.
    private func response(
        to request: KeyVoxStyleRewriteIPCRequest
    ) async throws -> (KeyVoxStyleRewriteIPCResponse, processingMode: String) {
        if isAppSessionWarm() {
            KeyVoxIPCBridge.writeStyleRewriteRequest(request)
            let response = try await waitForResponse(id: request.id)
            KeyVoxIPCBridge.clearStyleRewriteResponse()
            return (response, "app-ipc")
        }

        let response = await withCheckedContinuation { continuation in
            audioUnitClient.restyle(request, timeout: ResponseWait.timeout) { response in
                continuation.resume(returning: response)
            }
        }
        guard let response else {
            throw KeyboardStyleRewriteIPCError.audioUnitUnavailable
        }
        return (response, "transcription-au")
    }

    private func waitForResponse(id: UUID) async throws -> KeyVoxStyleRewriteIPCResponse {
        let deadline = Date().addingTimeInterval(ResponseWait.timeout)

        while Date() < deadline {
            if Task.isCancelled {
                throw KeyboardStyleRewriteIPCError.cancelled
            }

            if let response = KeyVoxIPCBridge.currentStyleRewriteResponse(),
               response.id == id {
                return response
            }

            try await Task.sleep(nanoseconds: ResponseWait.pollIntervalNanoseconds)
        }

        throw KeyboardStyleRewriteIPCError.timedOut
    }
}

private enum KeyboardStyleRewriteIPCError: Error, CustomStringConvertible {
    case cancelled
    case timedOut
    case audioUnitUnavailable

    var description: String {
        switch self {
        case .cancelled:
            return "cancelled"
        case .timedOut:
            return "timedOut"
        case .audioUnitUnavailable:
            return "audioUnitUnavailable"
        }
    }
}
