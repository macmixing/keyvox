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

    func testNormalizeReplacesParenthesesWithCommaAsides() {
        let normalized = PocketTTSChunkPlanner.normalize("Hello (world) today")
        XCTAssertTrue(normalized.text.hasSuffix("Hello, world, today."))
    }

    func testNormalizeSplitsHyphenatedWordsIntoSeparateWords() {
        let normalized = PocketTTSChunkPlanner.normalize("time-to-first audio")
        XCTAssertTrue(normalized.text.hasSuffix("Time to first audio."))
    }

    func testNormalizeReplacesEmailsWithPlaceholder() {
        let normalized = PocketTTSChunkPlanner.normalize("Email me at test@example.com")
        XCTAssertTrue(normalized.text.hasSuffix("Email me at email."))
    }

    func testNormalizeExpandsCurrencyAndPercentSymbols() {
        let normalized = PocketTTSChunkPlanner.normalize("It costs $12.50 and saves 30%")
        XCTAssertTrue(normalized.text.hasSuffix("It costs 12.50 dollars and saves 30 percent."))
    }

    func testNormalizeFlattensDatesAndTimes() {
        let normalized = PocketTTSChunkPlanner.normalize("Meet me on 04/04/2026 at 3:05 PM")
        XCTAssertTrue(normalized.text.hasSuffix("Meet me on 04 04 2026 at 3 05 PM."))
    }

    func testNormalizeConvertsColonsIntoSentencePauses() {
        let normalized = PocketTTSChunkPlanner.normalize("Agenda: review: launch")
        XCTAssertTrue(normalized.text.hasSuffix("Agenda. review. launch."))
    }

    func testNormalizePreservesTerminalPeriodsOnLinkListItems() {
        let normalized = PocketTTSChunkPlanner.normalize("- https://example.com")
        XCTAssertTrue(normalized.text.hasSuffix("- link."))
    }

    func testNormalizeStripsLiteralAsterisks() {
        let normalized = PocketTTSChunkPlanner.normalize("*important*")
        XCTAssertTrue(normalized.text.hasSuffix("Important."))
        XCTAssertFalse(normalized.text.contains("*"))
    }

    func testNormalizeStripsMarkdownAndCodeArtifacts() {
        let normalized = PocketTTSChunkPlanner.normalize("# Title\n- `inline_code`\nVisit [docs](https://example.com)")
        XCTAssertTrue(normalized.text.contains("Title"))
        XCTAssertTrue(normalized.text.contains("inline code"))
        XCTAssertTrue(normalized.text.contains("Visit docs"))
        XCTAssertFalse(normalized.text.contains("https://"))
        XCTAssertFalse(normalized.text.contains("`"))
    }

    func testNormalizeSplitsSnakeCaseCamelCaseAndSlashJoinedWords() {
        let normalized = PocketTTSChunkPlanner.normalize("snake_case camelCase and/or")
        XCTAssertTrue(normalized.text.hasSuffix("Snake case camel Case and or."))
    }

    func testNormalizeExpandsVersionPrefix() {
        let normalized = PocketTTSChunkPlanner.normalize("Updated in v1.2.3")
        XCTAssertTrue(normalized.text.hasSuffix("Updated in version 1.2.3."))
    }

    func testNormalizeAddsTerminalPeriodsToPlainLines() {
        let normalized = PocketTTSChunkPlanner.normalize("""
        hello world
        second line
        """)
        XCTAssertTrue(normalized.text.hasSuffix("Hello world. second line."))
    }

    func testNormalizePreservesExistingTerminalPunctuationAcrossLines() {
        let normalized = PocketTTSChunkPlanner.normalize("""
        hello world!
        second line
        """)
        XCTAssertTrue(normalized.text.hasSuffix("Hello world! second line."))
    }

    func testNormalizeAddsTerminalPeriodsToNumberedLists() {
        let normalized = PocketTTSChunkPlanner.normalize("""
        1. first item
        2. second item
        """)
        XCTAssertTrue(normalized.text.hasSuffix("1. first item. 2. second item."))
    }

    func testNormalizePreservesParenthesizedNumberedListMarkers() {
        let normalized = PocketTTSChunkPlanner.normalize("1) first item")
        XCTAssertTrue(normalized.text.hasSuffix("1) first item."))
        XCTAssertFalse(normalized.text.contains("1, first item."))
    }

    func testNormalizeAddsTerminalPeriodsToHyphenLists() {
        let normalized = PocketTTSChunkPlanner.normalize("""
        - first item
        - second item
        """)
        XCTAssertTrue(normalized.text.hasSuffix("- first item. - second item."))
    }

    func testNormalizeAddsTerminalPeriodsToBulletLists() {
        let normalized = PocketTTSChunkPlanner.normalize("""
        • first item
        • second item
        """)
        XCTAssertTrue(normalized.text.hasSuffix("- first item. - second item."))
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

    func testChunkPlannerUsesSaferChunkLimitForLongFormText() throws {
        let tokenizer = try SentencePieceTokenizer(modelData: fixtureSentencePieceModel())
        let longText = Array(repeating: "Dr. Smith arrived. The meeting started.", count: 40).joined(separator: " ")
        let chunks = PocketTTSChunkPlanner.chunk(longText, tokenizer: tokenizer)

        XCTAssertGreaterThan(chunks.count, 1)
        for chunk in chunks {
            XCTAssertLessThanOrEqual(
                tokenizer.encode(chunk).count,
                PocketTTSConstants.longFormMaxTokensPerChunk
            )
        }
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
