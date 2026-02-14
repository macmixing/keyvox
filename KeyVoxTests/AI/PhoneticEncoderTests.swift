import Foundation
import Testing
@testable import KeyVox

@MainActor
struct PhoneticEncoderTests {
    @Test
    func usesLexiconSignatureWhenAvailable() {
        let lexicon = FakeLexicon(pronunciations: ["cueboard": "KBRD"])
        let encoder = PhoneticEncoder()

        let signature = encoder.signature(for: "cueboard", lexicon: lexicon)
        #expect(signature == "KBRD")
    }

    @Test
    func fallbackSignatureIsDeterministic() {
        let lexicon = FakeLexicon()
        let encoder = PhoneticEncoder()

        let one = encoder.signature(for: "esposito", lexicon: lexicon)
        let two = encoder.signature(for: "esposito", lexicon: lexicon)

        #expect(!one.isEmpty)
        #expect(one == two)
    }

    @Test
    func phraseSignatureJoinsTokenSignatures() {
        let lexicon = FakeLexicon(pronunciations: ["migo": "MGO", "platform": "PLTRM"])
        let encoder = PhoneticEncoder()

        let signature = encoder.phraseSignature(for: ["migo", "platform"], lexicon: lexicon)
        #expect(signature == "MGO PLTRM")
    }
}
