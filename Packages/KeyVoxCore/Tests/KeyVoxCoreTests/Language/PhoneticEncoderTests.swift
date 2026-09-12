import Foundation
import XCTest
@testable import KeyVoxCore

@MainActor
final class PhoneticEncoderTests: LinguisticAnalyzerTestCase {
    func testUsesLexiconSignatureWhenAvailable() async {
        let lexicon = FakeLexicon(pronunciations: ["cueboard": "KBRD"])
        let encoder = PhoneticEncoder()

        let signature = encoder.signature(for: "cueboard", lexicon: lexicon)
        XCTAssertTrue(signature == "KBRD")
    }

    func testFallbackSignatureIsDeterministic() async {
        let lexicon = FakeLexicon()
        let encoder = PhoneticEncoder()

        let one = encoder.signature(for: "esposito", lexicon: lexicon)
        let two = encoder.signature(for: "esposito", lexicon: lexicon)

        XCTAssertTrue(!one.isEmpty)
        XCTAssertTrue(one == two)
    }

    func testPhraseSignatureJoinsTokenSignatures() async {
        let lexicon = FakeLexicon(pronunciations: ["migo": "MGO", "platform": "PLTRM"])
        let encoder = PhoneticEncoder()

        let signature = encoder.phraseSignature(for: ["migo", "platform"], lexicon: lexicon)
        XCTAssertTrue(signature == "MGO PLTRM")
    }

    func testNumericAndOrdinalTokensUseCardinalPronunciation() async {
        let lexicon = FakeLexicon(pronunciations: ["eleven": "IH-L-EH-V-AH-N"])
        let encoder = PhoneticEncoder()

        XCTAssertEqual(encoder.signature(for: "11", lexicon: lexicon), "IH-L-EH-V-AH-N")
        XCTAssertEqual(encoder.signature(for: "11th", lexicon: lexicon), "IH-L-EH-V-AH-N")
    }
}
