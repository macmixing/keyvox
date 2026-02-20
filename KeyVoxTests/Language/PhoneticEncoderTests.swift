import Foundation
import XCTest
@testable import KeyVox

@MainActor
final class PhoneticEncoderTests: XCTestCase {
    func testUsesLexiconSignatureWhenAvailable() {
        let lexicon = FakeLexicon(pronunciations: ["cueboard": "KBRD"])
        let encoder = PhoneticEncoder()

        let signature = encoder.signature(for: "cueboard", lexicon: lexicon)
        XCTAssertTrue(signature == "KBRD")
    }

    func testFallbackSignatureIsDeterministic() {
        let lexicon = FakeLexicon()
        let encoder = PhoneticEncoder()

        let one = encoder.signature(for: "esposito", lexicon: lexicon)
        let two = encoder.signature(for: "esposito", lexicon: lexicon)

        XCTAssertTrue(!one.isEmpty)
        XCTAssertTrue(one == two)
    }

    func testPhraseSignatureJoinsTokenSignatures() {
        let lexicon = FakeLexicon(pronunciations: ["migo": "MGO", "platform": "PLTRM"])
        let encoder = PhoneticEncoder()

        let signature = encoder.phraseSignature(for: ["migo", "platform"], lexicon: lexicon)
        XCTAssertTrue(signature == "MGO PLTRM")
    }
}
