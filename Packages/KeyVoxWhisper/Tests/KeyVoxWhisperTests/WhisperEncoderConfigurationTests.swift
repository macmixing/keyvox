import XCTest
@testable import KeyVoxWhisper

final class WhisperEncoderConfigurationTests: XCTestCase {
    func testEncoderIsConfiguredOnlyWhenRequestedAndContextExists() {
        for contextExists in [false, true] {
            for requested in [false, true] {
                var runtime = WhisperRuntime.live
                var calls = 0
                runtime.initFromFileWithParams = { _, _ in contextExists ? OpaquePointer(bitPattern: 1) : nil }
                runtime.freeContext = { _ in }
                runtime.configureEncoder = { _, _ in calls += 1; return true }
                let configuration = makeConfiguration()
                let whisper = Whisper(fromFileURL: configuration.modelURL,
                    encoderConfiguration: requested ? configuration : nil,
                    runtime: runtime,
                    osVersionProvider: { OperatingSystemVersion(majorVersion: 14, minorVersion: 0, patchVersion: 0) },
                    inferenceQueue: DispatchQueue.global())
                XCTAssertEqual(calls, contextExists && requested ? 1 : 0)
                XCTAssertEqual(whisper.isExternalEncoderConfigured, contextExists && requested)
            }
        }
    }

    func testUnavailableEncoderRetainsNativeInference() async throws {
        var runtime = WhisperRuntime.live
        var inferenceCalls = 0
        runtime.initFromFileWithParams = { _, _ in OpaquePointer(bitPattern: 1) }
        runtime.freeContext = { _ in }
        runtime.configureEncoder = { _, _ in false }
        runtime.fixedModelLanguageId = { _ in nil }
        runtime.full = { _, _, _, _ in inferenceCalls += 1; return 0 }
        runtime.fullNSegments = { _ in 0 }
        runtime.fullLangId = { _ in -1 }
        let configuration = makeConfiguration()
        let whisper = Whisper(fromFileURL: configuration.modelURL,
            encoderConfiguration: configuration, runtime: runtime,
            osVersionProvider: { OperatingSystemVersion(majorVersion: 14, minorVersion: 0, patchVersion: 0) },
            inferenceQueue: DispatchQueue.global())
        XCTAssertFalse(whisper.isExternalEncoderConfigured)
        let result = try await whisper.transcribe(audioFrames: [0])
        XCTAssertTrue(result.isEmpty)
        XCTAssertEqual(inferenceCalls, 1)
    }

    private func makeConfiguration() -> WhisperEncoderConfiguration {
        let directory = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent(UUID().uuidString)
        return WhisperEncoderConfiguration(pluginURL: directory.appendingPathComponent(UUID().uuidString),
            modelURL: directory.appendingPathComponent(UUID().uuidString), runtimeDirectory: directory)
    }
}
