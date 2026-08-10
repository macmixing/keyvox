import XCTest
@testable import KeyVoxCore

@MainActor
final class WhisperSegmentTextAssemblerTests: XCTestCase {
    func testLowercasesIncidentalContinuationCapitals() async {
        let assembler = makeAssembler()
        let text = await assembler.assemble(
            [
                "So I wanted to talk about this bug because like",
                "Everyone is talking about it and it seems to me that we need to fix it so I can stop",
                "Talking to myself randomly",
            ],
            normalizesContinuationCasing: true
        )

        XCTAssertEqual(
            text,
            "So I wanted to talk about this bug because like everyone is talking about it and it seems to me that we need to fix it so I can stop talking to myself randomly"
        )
    }

    func testPreservesProperNamesAndSentenceStarts() async {
        let assembler = makeAssembler()
        let samples = [
            (["I met", "Sarah yesterday"], "I met Sarah yesterday"),
            (["We use", "Apple devices"], "We use Apple devices"),
            (["I met", "Zarvox yesterday"], "I met Zarvox yesterday"),
            (["The first sentence ended.", "Everyone arrived"], "The first sentence ended. Everyone arrived"),
        ]

        for (segments, expected) in samples {
            let text = await assembler.assemble(
                segments,
                normalizesContinuationCasing: true
            )
            XCTAssertEqual(text, expected)
        }
    }

    func testLowercasesIncidentalCapitalAcrossChunkBoundary() async {
        let assembler = makeAssembler()
        let precedingText = "I just wanted to talk to you for a second because"

        let periodText = await assembler.assemble(
            ["Like."],
            after: precedingText,
            normalizesContinuationCasing: true
        )
        let commaText = await assembler.assemble(
            ["Like, everybody just wants to talk very slowly."],
            after: precedingText,
            normalizesContinuationCasing: true
        )

        XCTAssertEqual(periodText, "like.")
        XCTAssertEqual(commaText, "like, everybody just wants to talk very slowly.")
    }

    private func makeAssembler() -> WhisperSegmentTextAssembler {
        WhisperSegmentTextAssembler(
            pronunciationLookup: PronunciationLookup(
                pronunciationsByWord: [
                    "apple": "AE-P-AH-L",
                    "everyone": "EH-V-R-IY-W-AH-N",
                    "like": "L-AY-K",
                    "sarah": "S-EH-R-AH",
                    "talking": "T-AO-K-IH-NG",
                ]
            )
        )
    }
}
