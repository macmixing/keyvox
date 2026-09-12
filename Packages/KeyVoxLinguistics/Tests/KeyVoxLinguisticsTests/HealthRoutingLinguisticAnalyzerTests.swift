import Foundation
import XCTest
@testable import KeyVoxLinguistics

final class HealthRoutingLinguisticAnalyzerTests: XCTestCase {
    func testHealthyPrimaryDoesNotCreateFallback() {
        let text = #function
        let fallbackFactoryCalls = LockedCounter()
        let primary = FixedAnalyzer { text, features in
            LinguisticAnalysis(
                tokens: [Self.token(in: text, role: .noun, identity: .ordinaryWord)],
                availableFeatures: features
            )
        }
        let router = HealthRoutingLinguisticAnalyzer(
            primary: primary,
            fallbackFactory: {
                fallbackFactoryCalls.increment()
                return FixedAnalyzer { _, _ in
                    XCTFail("Fallback must not be created for healthy evidence")
                    return LinguisticAnalysis(tokens: [], availableFeatures: [])
                }
            },
            diagnosticHandler: { _ in }
        )

        let result = router.analyze(
            text,
            range: nil,
            languageCode: nil,
            features: [.roles, .wordBoundaries],
            grouping: .words
        )

        XCTAssertEqual(result.tokens.first?.role, .noun)
        XCTAssertEqual(fallbackFactoryCalls.value, 0)
    }

    func testCollapsedPrimarySelectsAndLatchesFallback() {
        let text = #function
        let primaryCalls = LockedCounter()
        let fallbackCalls = LockedCounter()
        let primary = FixedAnalyzer { text, features in
            primaryCalls.increment()
            return LinguisticAnalysis(
                tokens: [Self.token(in: text, role: .otherWord, identity: .ordinaryWord)],
                availableFeatures: features
            )
        }
        let fallback = FixedAnalyzer { text, features in
            fallbackCalls.increment()
            return LinguisticAnalysis(
                tokens: [Self.token(in: text, role: .verb, identity: .ordinaryWord)],
                availableFeatures: features
            )
        }
        let router = HealthRoutingLinguisticAnalyzer(
            primary: primary,
            fallbackFactory: { fallback },
            diagnosticHandler: { _ in }
        )

        for _ in text.indices.prefix(2) {
            _ = router.analyze(
                text,
                range: nil,
                languageCode: nil,
                features: [.roles, .wordBoundaries],
                grouping: .words
            )
        }

        XCTAssertEqual(primaryCalls.value, 1)
        XCTAssertEqual(fallbackCalls.value, 2)
    }

    func testNonlexicalInputDoesNotSelectFallback() {
        let fallbackFactoryCalls = LockedCounter()
        let router = HealthRoutingLinguisticAnalyzer(
            primary: FixedAnalyzer { _, _ in
                LinguisticAnalysis(tokens: [], availableFeatures: [])
            },
            fallbackFactory: {
                fallbackFactoryCalls.increment()
                return nil
            },
            diagnosticHandler: { _ in }
        )

        _ = router.analyze(
            String(repeating: Character("."), count: #line),
            range: nil,
            languageCode: nil,
            features: [.roles, .wordBoundaries],
            grouping: .words
        )

        XCTAssertEqual(fallbackFactoryCalls.value, 0)
    }

    func testAvailableNameCapabilityDoesNotRequireANameMatch() {
        let text = #function
        let fallbackFactoryCalls = LockedCounter()
        let router = HealthRoutingLinguisticAnalyzer(
            primary: FixedAnalyzer { text, features in
                LinguisticAnalysis(
                    tokens: [Self.token(in: text, role: .noun, identity: .unknown)],
                    availableFeatures: features
                )
            },
            fallbackFactory: {
                fallbackFactoryCalls.increment()
                return nil
            },
            diagnosticHandler: { _ in }
        )

        _ = router.analyze(
            text,
            range: nil,
            languageCode: nil,
            features: [.names, .wordBoundaries],
            grouping: .words
        )

        XCTAssertEqual(fallbackFactoryCalls.value, 0)
    }

    func testUnavailableFallbackFactoryIsResolvedOnlyOnce() {
        let text = #function
        let fallbackFactoryCalls = LockedCounter()
        let router = HealthRoutingLinguisticAnalyzer(
            primary: FixedAnalyzer { text, features in
                LinguisticAnalysis(
                    tokens: [Self.token(in: text, role: .otherWord, identity: .unknown)],
                    availableFeatures: features
                )
            },
            fallbackFactory: {
                fallbackFactoryCalls.increment()
                return nil
            },
            diagnosticHandler: { _ in }
        )

        for _ in text.indices.prefix(2) {
            _ = router.analyze(
                text,
                range: nil,
                languageCode: nil,
                features: [.roles, .wordBoundaries],
                grouping: .words
            )
        }

        XCTAssertEqual(fallbackFactoryCalls.value, 1)
    }

    private static func token(
        in text: String,
        role: LexicalRole,
        identity: LinguisticToken.Identity
    ) -> LinguisticToken {
        LinguisticToken(
            range: NSRange(text.startIndex..<text.endIndex, in: text),
            role: role,
            identity: identity
        )
    }
}

private struct FixedAnalyzer: LinguisticAnalyzing {
    let result: @Sendable (String, LinguisticFeatures) -> LinguisticAnalysis

    func analyze(
        _ text: String,
        range: NSRange?,
        languageCode: String?,
        features: LinguisticFeatures,
        grouping: LinguisticGrouping
    ) -> LinguisticAnalysis {
        result(text, features)
    }
}

private final class LockedCounter: @unchecked Sendable {
    private let lock = NSLock()
    private var storage = 0

    var value: Int { lock.withLock { storage } }

    func increment() {
        lock.withLock { storage += 1 }
    }
}
