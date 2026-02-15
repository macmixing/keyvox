import Foundation
import XCTest
@testable import KeyVox

@MainActor
final class AppUpdateServiceTests: XCTestCase {
    func testManualCheckShowsNoUpdatePromptWhenRemoteNotNewer() async throws {
        let promptPresenter = RecordingPromptPresenter()
        let now = MutableNow(Date(timeIntervalSince1970: 1_700_000_000))
        let session = makeMockSession()

        MockURLProtocol.handler = { _ in
            let data = self.releaseData(tag: "0.0.0", htmlURL: "https://github.com/macmixing/keyvox/releases/tag/v0.0.0", body: "No update")
            return (self.okResponse(), data)
        }

        let service = makeService(promptPresenter: promptPresenter, now: now, session: session, checkInterval: 60 * 60 * 24)
        service.checkForUpdatesManually()
        try await waitForCondition { promptPresenter.prompts.count == 1 }

        XCTAssertTrue(promptPresenter.prompts[0].title == "You're Up to Date")
        XCTAssertTrue(service.latestRemoteInfo?.version == "0.0.0")
    }

    func testAutoCheckShowsUpdatePromptForNewerVersion() async throws {
        let promptPresenter = RecordingPromptPresenter()
        let now = MutableNow(Date(timeIntervalSince1970: 1_700_000_000))
        let session = makeMockSession()

        MockURLProtocol.handler = { _ in
            let data = self.releaseData(
                tag: "999.0.0",
                htmlURL: "https://github.com/macmixing/keyvox/releases/tag/v999.0.0",
                body: "Major release",
                dmgURL: "https://github.com/macmixing/keyvox/releases/download/v999.0.0/KeyVox-999.0.0.dmg"
            )
            return (self.okResponse(), data)
        }

        let service = makeService(promptPresenter: promptPresenter, now: now, session: session, checkInterval: 60 * 60 * 24)
        service.checkForUpdatesIfNeeded()
        try await waitForCondition { promptPresenter.prompts.count == 1 }

        XCTAssertTrue(promptPresenter.prompts[0].title == "KeyVox Update Available")
        XCTAssertTrue(service.latestRemoteInfo?.version == "999.0.0")
    }

    func testCheckSkipsPromptWhenUpdateUrlHostNotAllowlisted() async throws {
        let promptPresenter = RecordingPromptPresenter()
        let now = MutableNow(Date(timeIntervalSince1970: 1_700_000_000))
        let session = makeMockSession()

        MockURLProtocol.handler = { _ in
            let data = self.releaseData(tag: "999.0.0", htmlURL: "https://evil.example.com/releases/v999", body: "Bad host")
            return (self.okResponse(), data)
        }

        let service = makeService(promptPresenter: promptPresenter, now: now, session: session, checkInterval: 60 * 60 * 24)
        service.checkForUpdatesIfNeeded()
        try await Task.sleep(nanoseconds: 200_000_000)

        XCTAssertTrue(promptPresenter.prompts.isEmpty)
        XCTAssertTrue(service.latestRemoteInfo == nil)
    }

    func testAutoPromptCooldownIsPerLaunchAndIntervalBounded() async throws {
        let promptPresenter = RecordingPromptPresenter()
        let now = MutableNow(Date(timeIntervalSince1970: 1_700_000_000))
        let session = makeMockSession()

        MockURLProtocol.handler = { _ in
            let data = self.releaseData(
                tag: "999.0.0",
                htmlURL: "https://github.com/macmixing/keyvox/releases/tag/v999.0.0",
                body: "Major release",
                dmgURL: "https://github.com/macmixing/keyvox/releases/download/v999.0.0/KeyVox-999.0.0.dmg"
            )
            return (self.okResponse(), data)
        }

        let service = makeService(promptPresenter: promptPresenter, now: now, session: session, checkInterval: 5)

        service.checkForUpdatesIfNeeded()
        try await waitForCondition { promptPresenter.prompts.count == 1 }

        promptPresenter.prompts[0].onDismiss()

        service.checkForUpdatesIfNeeded()
        try await Task.sleep(nanoseconds: 200_000_000)
        XCTAssertTrue(promptPresenter.prompts.count == 1)

        now.advance(by: 6)
        service.checkForUpdatesIfNeeded()
        try await waitForCondition { promptPresenter.prompts.count == 2 }
    }

    private func makeService(
        promptPresenter: RecordingPromptPresenter,
        now: MutableNow,
        session: URLSession,
        checkInterval: TimeInterval
    ) -> AppUpdateService {
        AppUpdateService(
            feedConfig: .trackedDefault,
            bundle: .main,
            urlSession: session,
            promptPresenter: promptPresenter,
            nowProvider: { now.value },
            checkInterval: checkInterval
        )
    }

    private func okResponse() -> HTTPURLResponse {
        HTTPURLResponse(
            url: URL(string: "https://api.github.com/repos/macmixing/keyvox/releases/latest")!,
            statusCode: 200,
            httpVersion: nil,
            headerFields: nil
        )!
    }

    private func releaseData(tag: String, htmlURL: String, body: String, dmgURL: String? = nil) -> Data {
        let assetsJSON: String
        if let dmgURL {
            assetsJSON = "[{\"name\":\"KeyVox.dmg\",\"browser_download_url\":\"\(dmgURL)\"}]"
        } else {
            assetsJSON = "[]"
        }

        let json = """
        {
          "tag_name": "\(tag)",
          "body": "\(body)",
          "html_url": "\(htmlURL)",
          "assets": \(assetsJSON)
        }
        """
        return Data(json.utf8)
    }
}
