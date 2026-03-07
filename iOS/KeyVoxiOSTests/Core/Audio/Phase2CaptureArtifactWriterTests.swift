import Foundation
import Testing
@testable import KeyVox_iOS

@MainActor
struct Phase2CaptureArtifactWriterTests {
    @Test func writesSnapshotMetadataAndOptionalTranscriptionInput() async throws {
        let directory = makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }

        let writer = Phase2CaptureArtifactWriter(baseDirectoryURL: directory)
        let artifact = try await writer.writeLatestCapture(
            Phase2CaptureWriteRequest(
                capturedAt: Date(timeIntervalSince1970: 100),
                sampleRate: 16_000,
                snapshotFrames: [0.1, -0.1, 0.2],
                outputFrames: [0.25, -0.25],
                captureDuration: 1.2,
                hadActiveSignal: true,
                wasAbsoluteSilence: false,
                wasLikelySilence: false,
                wasLongTrueSilence: false,
                maxActiveSignalRunDuration: 0.6,
                currentCaptureDeviceName: "iPhone Microphone"
            )
        )

        #expect(FileManager.default.fileExists(atPath: artifact.snapshotWAVURL.path))
        #expect(FileManager.default.fileExists(atPath: artifact.metadataURL.path))
        #expect(artifact.transcriptionInputWAVURL != nil)
        #expect(FileManager.default.fileExists(atPath: artifact.transcriptionInputWAVURL!.path))

        let metadata = try Data(contentsOf: artifact.metadataURL)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let decoded = try decoder.decode(Phase2CaptureArtifact.self, from: metadata)
        #expect(decoded == artifact)
    }

    @Test func omitsAndRemovesTranscriptionInputWhenOutputIsEmpty() async throws {
        let directory = makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }

        let writer = Phase2CaptureArtifactWriter(baseDirectoryURL: directory)
        _ = try await writer.writeLatestCapture(
            Phase2CaptureWriteRequest(
                capturedAt: Date(),
                sampleRate: 16_000,
                snapshotFrames: [0.1, 0.2, 0.3],
                outputFrames: [0.1],
                captureDuration: 0.5,
                hadActiveSignal: true,
                wasAbsoluteSilence: false,
                wasLikelySilence: false,
                wasLongTrueSilence: false,
                maxActiveSignalRunDuration: 0.4,
                currentCaptureDeviceName: "iPhone Microphone"
            )
        )

        let artifact = try await writer.writeLatestCapture(
            Phase2CaptureWriteRequest(
                capturedAt: Date(),
                sampleRate: 16_000,
                snapshotFrames: [0, 0, 0],
                outputFrames: [],
                captureDuration: 3.5,
                hadActiveSignal: false,
                wasAbsoluteSilence: true,
                wasLikelySilence: false,
                wasLongTrueSilence: true,
                maxActiveSignalRunDuration: 0,
                currentCaptureDeviceName: "iPhone Microphone"
            )
        )

        #expect(artifact.transcriptionInputWAVURL == nil)
        #expect(!FileManager.default.fileExists(atPath: directory.appendingPathComponent("latest-transcription-input.wav").path))
    }

    @Test func writesMono16kPCMHeader() async throws {
        let directory = makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }

        let writer = Phase2CaptureArtifactWriter(baseDirectoryURL: directory)
        let artifact = try await writer.writeLatestCapture(
            Phase2CaptureWriteRequest(
                capturedAt: Date(),
                sampleRate: 16_000,
                snapshotFrames: [0.1, -0.1, 0.3, -0.3],
                outputFrames: [],
                captureDuration: 0.4,
                hadActiveSignal: true,
                wasAbsoluteSilence: false,
                wasLikelySilence: false,
                wasLongTrueSilence: false,
                maxActiveSignalRunDuration: 0.2,
                currentCaptureDeviceName: "iPhone Microphone"
            )
        )

        let data = try Data(contentsOf: artifact.snapshotWAVURL)
        #expect(String(decoding: data[0..<4], as: UTF8.self) == "RIFF")
        #expect(String(decoding: data[8..<12], as: UTF8.self) == "WAVE")
        #expect(UInt16(littleEndianData: data[22..<24]) == 1)
        #expect(UInt32(littleEndianData: data[24..<28]) == 16_000)
        #expect(UInt16(littleEndianData: data[34..<36]) == 16)
    }

    private func makeTemporaryDirectory() -> URL {
        let url = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }
}

private extension UInt16 {
    init(littleEndianData data: Data.SubSequence) {
        self = data.withUnsafeBytes { $0.load(as: UInt16.self) }.littleEndian
    }
}

private extension UInt32 {
    init(littleEndianData data: Data.SubSequence) {
        self = data.withUnsafeBytes { $0.load(as: UInt32.self) }.littleEndian
    }
}
