import Foundation

public final class HealthRoutingLinguisticAnalyzer: LinguisticAnalyzing, @unchecked Sendable {
    public typealias FallbackFactory = @Sendable () -> (any LinguisticAnalyzing)?
    public typealias DiagnosticHandler = @Sendable (String) -> Void

    private let primary: any LinguisticAnalyzing
    private let fallbackFactory: FallbackFactory
    private let diagnosticHandler: DiagnosticHandler
    private let stateLock = NSLock()
    private let fallbackLock = NSLock()
    private var fallback: (any LinguisticAnalyzing)?
    private var didResolveFallback = false
    private var fallbackLanguages = Set<LanguageKey>()
    private var reportedPrimaryLanguages = Set<LanguageKey>()
    private var reportedUnavailableFallbackLanguages = Set<LanguageKey>()

    public init(
        primary: any LinguisticAnalyzing,
        fallbackFactory: @escaping FallbackFactory,
        diagnosticHandler: @escaping DiagnosticHandler = { print("[KVXLinguistics] \($0)") }
    ) {
        self.primary = primary
        self.fallbackFactory = fallbackFactory
        self.diagnosticHandler = diagnosticHandler
    }

    public func analyze(
        _ text: String,
        range: NSRange?,
        languageCode: String?,
        features: LinguisticFeatures,
        grouping: LinguisticGrouping
    ) -> LinguisticAnalysis {
        let languageKey = LanguageKey(languageCode)
        if usesFallback(for: languageKey), let fallback = resolvedFallback() {
            return fallback.analyze(
                text,
                range: range,
                languageCode: languageCode,
                features: features,
                grouping: grouping
            )
        }

        let primaryResult = primary.analyze(
            text,
            range: range,
            languageCode: languageCode,
            features: features,
            grouping: grouping
        )
        switch LinguisticAnalysisHealth.evaluate(
            text: text,
            requestedFeatures: features,
            analysis: primaryResult
        ) {
        case .healthy:
            reportPrimaryIfNeeded(for: languageKey)
            return primaryResult
        case .inconclusive:
            return primaryResult
        case .unhealthy(let reason):
            guard let fallback = resolvedFallback() else {
                reportUnavailableFallbackIfNeeded(for: languageKey, reason: reason)
                return primaryResult
            }
            selectFallback(for: languageKey, reason: reason)
            return fallback.analyze(
                text,
                range: range,
                languageCode: languageCode,
                features: features,
                grouping: grouping
            )
        }
    }

    private func resolvedFallback() -> (any LinguisticAnalyzing)? {
        fallbackLock.withLock {
            if didResolveFallback { return fallback }
            let resolved = fallbackFactory()
            fallback = resolved
            didResolveFallback = true
            return resolved
        }
    }

    private func usesFallback(for language: LanguageKey) -> Bool {
        stateLock.withLock { fallbackLanguages.contains(language) }
    }

    private func selectFallback(for language: LanguageKey, reason: LinguisticAnalysisHealth.Reason) {
        let inserted = stateLock.withLock { fallbackLanguages.insert(language).inserted }
        if inserted {
            diagnosticHandler("provider=fallback language=\(language.description) reason=\(reason.rawValue)")
        }
    }

    private func reportPrimaryIfNeeded(for language: LanguageKey) {
        let inserted = stateLock.withLock { reportedPrimaryLanguages.insert(language).inserted }
        if inserted {
            diagnosticHandler("provider=primary language=\(language.description) health=healthy")
        }
    }

    private func reportUnavailableFallbackIfNeeded(
        for language: LanguageKey,
        reason: LinguisticAnalysisHealth.Reason
    ) {
        let inserted = stateLock.withLock { reportedUnavailableFallbackLanguages.insert(language).inserted }
        if inserted {
            diagnosticHandler(
                "provider=primary language=\(language.description) health=unhealthy "
                    + "reason=\(reason.rawValue) fallback=unavailable"
            )
        }
    }
}

private struct LanguageKey: Hashable {
    private let value: String?

    init(_ languageCode: String?) {
        value = languageCode.flatMap(ModelLanguageIdentifier.base)
    }

    var description: String { value ?? "undetermined" }
}
