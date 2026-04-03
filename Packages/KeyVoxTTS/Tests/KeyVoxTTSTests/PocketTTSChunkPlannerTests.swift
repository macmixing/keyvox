import XCTest
@testable import KeyVoxTTS

final class PocketTTSChunkPlannerTests: XCTestCase {
    func testNormalizeAddsTerminalPunctuation() {
        let normalized = PocketTTSChunkPlanner.normalize("hello world")
        XCTAssertEqual(normalized.text, "        Hello world.")
    }

    func testNormalizePadsShortText() {
        let normalized = PocketTTSChunkPlanner.normalize("hi")
        XCTAssertTrue(normalized.text.hasSuffix("Hi."))
        XCTAssertEqual(normalized.framesAfterEOS, PocketTTSConstants.shortTextPadFrames)
    }

    func testNormalizeSanitizesLinksAndChevronBullets() {
        let normalized = PocketTTSChunkPlanner.normalize("""
        Fellow patriots - visit https://example.com now
        >>> Require voter ID
        """)
        XCTAssertFalse(normalized.text.contains("https://"))
        XCTAssertFalse(normalized.text.contains(">>>"))
        XCTAssertTrue(normalized.text.contains("link"))
        XCTAssertTrue(normalized.text.contains("Require voter ID"))
    }

    func testChunkPlannerKeepsShortTextInSingleChunk() throws {
        let tokenizer = try SentencePieceTokenizer(modelData: fixtureSentencePieceModel())
        let chunks = PocketTTSChunkPlanner.chunk("Dr. Smith arrived. The meeting started.", tokenizer: tokenizer)
        XCTAssertEqual(chunks, ["Dr. Smith arrived. The meeting started."])
    }

    func testChunkPlannerPreservesQuotedSentenceBoundaries() throws {
        let tokenizer = try SentencePieceTokenizer(modelData: fixtureSentencePieceModel())
        let chunks = PocketTTSChunkPlanner.chunk("She said, \"Wait.\" Then he left.", tokenizer: tokenizer)
        XCTAssertEqual(chunks, ["She said, \"Wait.\" Then he left."])
    }

    func testChunkPlannerDoesNotSplitDecimalSentences() throws {
        let tokenizer = try SentencePieceTokenizer(modelData: fixtureSentencePieceModel())
        let chunks = PocketTTSChunkPlanner.chunk("Version 2.5 is ready. Ship it.", tokenizer: tokenizer)
        XCTAssertEqual(chunks, ["Version 2.5 is ready. Ship it."])
    }

    private func fixtureSentencePieceModel() throws -> Data {
        func varint(_ value: Int) -> [UInt8] {
            var remaining = UInt64(value)
            var bytes: [UInt8] = []
            while true {
                var byte = UInt8(remaining & 0x7F)
                remaining >>= 7
                if remaining != 0 {
                    byte |= 0x80
                }
                bytes.append(byte)
                if remaining == 0 {
                    return bytes
                }
            }
        }

        func pieceMessage(token: String, score: Float) -> [UInt8] {
            var payload: [UInt8] = []
            let tokenBytes = Array(token.utf8)
            payload.append(0x0A)
            payload.append(contentsOf: varint(tokenBytes.count))
            payload.append(contentsOf: tokenBytes)

            payload.append(0x15)
            payload.append(contentsOf: withUnsafeBytes(of: score.bitPattern.littleEndian, Array.init))
            return payload
        }

        let pieces = [
            "▁", "Dr", ".", "Smith", "arrived", "The", "meeting", "started",
            "She", "said", ",", "\"", "Wait", "Then", "he", "left",
            "Version", "2", "5", "is", "ready", "Ship", "it",
        ]

        var data: [UInt8] = []
        for (index, token) in pieces.enumerated() {
            let payload = pieceMessage(token: token, score: Float(100 - index))
            data.append(0x0A)
            data.append(contentsOf: varint(payload.count))
            data.append(contentsOf: payload)
        }

        return Data(data)
    }
}
