import Foundation

public enum LinguisticAnalyzerFactory {
    public typealias ResourceDirectoryProvider = @Sendable () -> URL?

    public static func healthRouted(
        preferred: any LinguisticAnalyzing = TextLinguistics.provider,
        portableResourceDirectory: @escaping ResourceDirectoryProvider,
        portableLanguageCode: String,
        diagnosticHandler: @escaping HealthRoutingLinguisticAnalyzer.DiagnosticHandler = {
            print("[KVXLinguistics] \($0)")
        }
    ) -> any LinguisticAnalyzing {
        HealthRoutingLinguisticAnalyzer(
            primary: preferred,
            fallbackFactory: {
                guard let resourceDirectory = portableResourceDirectory() else {
                    diagnosticHandler("provider=fallback load=failed reason=missing-resource-directory")
                    return nil
                }

                do {
                    return try PerceptronLinguisticAnalyzer(
                        modelDirectory: resourceDirectory.appendingPathComponent(
                            "averaged-perceptron-tagger-eng",
                            isDirectory: true
                        ),
                        lexicalDatabaseDirectory: resourceDirectory.appendingPathComponent(
                            "wordnet-3.0",
                            isDirectory: true
                        ),
                        languageCode: portableLanguageCode
                    )
                } catch {
                    diagnosticHandler("provider=fallback load=failed error=\(String(describing: error))")
                    return nil
                }
            },
            diagnosticHandler: diagnosticHandler
        )
    }
}
