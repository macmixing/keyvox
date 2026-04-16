import Foundation
import KeyVoxTTS
import Testing
@testable import KeyVox_iOS

struct PocketTTSEngineTests {
    @Test func lifecyclePreparationDoesNotInstantiateRuntimeWhenUnloaded() async {
        let harness = makeHarness()

        await harness.engine.prepareForForegroundSynthesis()
        await harness.engine.prepareForBackgroundContinuation()

        #expect(harness.factoryProbe.createCallCount == 0)
        #expect(harness.runtime.prepareCount == 0)
        #expect(harness.runtime.preferredModes.isEmpty)
    }

    @Test func explicitPreparationOwnsRuntimeUntilUnload() async throws {
        let harness = makeHarness()

        try await harness.engine.prepareIfNeeded()
        await harness.engine.prepareForForegroundSynthesis()
        await harness.engine.prepareForBackgroundContinuation()
        await harness.engine.unloadIfNeeded()
        await harness.engine.prepareForForegroundSynthesis()
        try await harness.engine.prepareIfNeeded()

        #expect(harness.factoryProbe.createCallCount == 2)
        #expect(harness.runtime.prepareCount == 1)
        #expect(harness.recreatedRuntime.prepareCount == 1)
        #expect(harness.runtime.preferredModes.count == 2)
        #expect(matches(harness.runtime.preferredModes[safe: 0], .foreground))
        #expect(matches(harness.runtime.preferredModes[safe: 1], .backgroundSafe))
        #expect(harness.recreatedRuntime.preferredModes.isEmpty)
    }

    private func makeHarness() -> PocketTTSEngineHarness {
        let assetLayout = KeyVoxTTSAssetLayout(
            rootDirectoryURL: URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
                .appendingPathComponent(UUID().uuidString, isDirectory: true)
        )
        let factoryProbe = RuntimeFactoryProbe()
        let runtime = SpyPocketTTSEngineRuntime()
        let recreatedRuntime = SpyPocketTTSEngineRuntime()
        let engine = PocketTTSEngine(
            fileManager: .default,
            assetLayoutProvider: { assetLayout },
            sharedModelInstalledProvider: { true },
            runtimeFactory: { _ in
                factoryProbe.createCallCount += 1
                return factoryProbe.createCallCount == 1 ? runtime : recreatedRuntime
            }
        )

        return PocketTTSEngineHarness(
            engine: engine,
            factoryProbe: factoryProbe,
            runtime: runtime,
            recreatedRuntime: recreatedRuntime
        )
    }
}

private func matches(_ mode: KeyVoxTTSComputeMode?, _ expected: KeyVoxTTSComputeMode) -> Bool {
    mode == expected
}

private extension Array {
    subscript(safe index: Int) -> Element? {
        guard indices.contains(index) else { return nil }
        return self[index]
    }
}

private struct PocketTTSEngineHarness {
    let engine: PocketTTSEngine
    let factoryProbe: RuntimeFactoryProbe
    let runtime: SpyPocketTTSEngineRuntime
    let recreatedRuntime: SpyPocketTTSEngineRuntime
}

private final class RuntimeFactoryProbe {
    var createCallCount = 0
}

private final class SpyPocketTTSEngineRuntime: PocketTTSEngineRuntime {
    private(set) var prepareCount = 0
    private(set) var preferredModes: [KeyVoxTTSComputeMode] = []

    func prepareIfNeeded() async throws {
        prepareCount += 1
    }

    func prepareVoiceIfNeeded(_ voice: KeyVoxTTSVoice) async throws {}

    func setPreferredComputeMode(_ mode: KeyVoxTTSComputeMode) async {
        preferredModes.append(mode)
    }

    func requestPreferredComputeMode(_ mode: KeyVoxTTSComputeMode) {}

    func synthesizeStreaming(
        text: String,
        voice: KeyVoxTTSVoice,
        fastModeEnabled: Bool
    ) async throws -> AsyncThrowingStream<KeyVoxTTSAudioFrame, Error> {
        AsyncThrowingStream { continuation in
            continuation.finish()
        }
    }
}
