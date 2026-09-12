import Foundation
import KeyVoxLinguistics

@main
struct AppleLinguisticProbe {
    static func main() {
        for text in CommandLine.arguments.dropFirst() {
            let analysis = TextLinguistics.analyze(
                text,
                features: [.roles, .lemmas, .names, .wordBoundaries]
            )
            print("input=\(String(reflecting: text)) available=\(analysis.availableFeatures.rawValue)")
            for token in analysis.tokens {
                let value = (text as NSString).substring(with: token.range)
                print(
                    "  token=\(String(reflecting: value)) range=\(token.range.location):\(token.range.length) "
                        + "role=\(token.role.map { String(describing: $0) } ?? "-") "
                        + "lemma=\(token.lemma ?? "-") identity=\(token.identity) inflection=\(token.inflection)"
                )
            }
        }
    }
}
