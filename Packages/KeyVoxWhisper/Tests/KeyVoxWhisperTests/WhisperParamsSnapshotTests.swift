import XCTest
@testable import KeyVoxWhisper

final class WhisperParamsSnapshotTests: XCTestCase {
    func testSnapshotRetainsOwnedStringsAfterParametersChangeAndRelease() {
        var params: WhisperParams? = .default
        let prompt = UUID().uuidString
        params?.initialPrompt = prompt
        let language = params!.language
        let snapshot = params!.snapshot()

        params?.initialPrompt = UUID().uuidString
        params?.language = .auto
        params = nil

        XCTAssertEqual(String(cString: snapshot.raw.initial_prompt!), prompt)
        XCTAssertEqual(String(cString: snapshot.raw.language!), language.rawValue)
    }

    func testSnapshotPreservesEmptyPrompt() {
        let params = WhisperParams.default
        params.initialPrompt = UUID().uuidString
        params.initialPrompt = ""
        XCTAssertNil(params.snapshot().raw.initial_prompt)
    }
}
