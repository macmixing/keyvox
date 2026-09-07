import Foundation
import KeyVoxLinguistics
import XCTest
@testable import KeyVoxCore

final class LinguisticProviderIntegrationTests: XCTestCase {
    func testSelectedProviderSurvivesAsyncProcessingQueue() async {
        let provider = RecordingLinguisticAnalyzer(base: TextLinguistics.provider)
        let processor = TranscriptionPostProcessor(linguisticAnalyzer: provider)
        let input = UUID().uuidString.lowercased()
        let synchronous = processor.process(input, dictionaryEntries: [], renderMode: .singleLineInline)
        let callsAfterSync = provider.callCount
        let asynchronous = await processor.processAsync(input, dictionaryEntries: [], renderMode: .singleLineInline)
        XCTAssertGreaterThan(callsAfterSync, 0)
        XCTAssertGreaterThan(provider.callCount, callsAfterSync)
        XCTAssertEqual(asynchronous, synchronous)
    }
}

private final class RecordingLinguisticAnalyzer: LinguisticAnalyzing, @unchecked Sendable {
    private let base: any LinguisticAnalyzing
    private let lock = NSLock()
    private var calls = 0

    init(base: any LinguisticAnalyzing) { self.base = base }
    var callCount: Int { lock.withLock { calls } }

    func analyze(_ text: String, range: NSRange?, languageCode: String?, features: LinguisticFeatures, grouping: LinguisticGrouping) -> LinguisticAnalysis {
        lock.withLock { calls += 1 }
        return base.analyze(text, range: range, languageCode: languageCode, features: features, grouping: grouping)
    }
}
