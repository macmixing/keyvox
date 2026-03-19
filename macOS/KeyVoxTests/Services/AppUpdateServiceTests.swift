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
        XCTAssertTrue(promptPresenter.prompts[0].primaryButtonTitle == "Open Updater")
    }

    func testUpdatePromptUsesSummarySectionWhenPresent() async throws {
        let promptPresenter = RecordingPromptPresenter()
        let now = MutableNow(Date(timeIntervalSince1970: 1_700_000_000))
        let session = makeMockSession()

        MockURLProtocol.handler = { _ in
            let body = """
            Intro text that should not appear.

            ## Summary
            Faster startup time
            Better paste reliability

            ## Details
            Full details follow here.
            """
            let data = self.releaseData(
                tag: "999.0.0",
                htmlURL: "https://github.com/macmixing/keyvox/releases/tag/v999.0.0",
                body: body,
                dmgURL: "https://github.com/macmixing/keyvox/releases/download/v999.0.0/KeyVox-999.0.0.dmg"
            )
            return (self.okResponse(), data)
        }

        let service = makeService(promptPresenter: promptPresenter, now: now, session: session, checkInterval: 60 * 60 * 24)
        service.checkForUpdatesIfNeeded()
        try await waitForCondition { promptPresenter.prompts.count == 1 }

        XCTAssertTrue(promptPresenter.prompts[0].message == "Faster startup time\nBetter paste reliability")
    }

    func testUpdatePromptFallsBackToShortPreviewWithoutSummary() async throws {
        let promptPresenter = RecordingPromptPresenter()
        let now = MutableNow(Date(timeIntervalSince1970: 1_700_000_000))
        let session = makeMockSession()

        MockURLProtocol.handler = { _ in
            let body = """
            Line 1
            Line 2
            Line 3
            Line 4
            Line 5 should be trimmed
            """
            let data = self.releaseData(
                tag: "999.0.0",
                htmlURL: "https://github.com/macmixing/keyvox/releases/tag/v999.0.0",
                body: body,
                dmgURL: "https://github.com/macmixing/keyvox/releases/download/v999.0.0/KeyVox-999.0.0.dmg"
            )
            return (self.okResponse(), data)
        }

        let service = makeService(promptPresenter: promptPresenter, now: now, session: session, checkInterval: 60 * 60 * 24)
        service.checkForUpdatesIfNeeded()
        try await waitForCondition { promptPresenter.prompts.count == 1 }

        XCTAssertTrue(promptPresenter.prompts[0].message == "Line 1\nLine 2\nLine 3\nLine 4…")
    }

    func testUpdatePromptStripsBasicMarkdownFormatting() async throws {
        let promptPresenter = RecordingPromptPresenter()
        let now = MutableNow(Date(timeIntervalSince1970: 1_700_000_000))
        let session = makeMockSession()

        MockURLProtocol.handler = { _ in
            let body = """
            ## **KeyVox v1.0.0** - Initial Public Release
            **Release date:** March 1, 2026
            """
            let data = self.releaseData(
                tag: "999.0.0",
                htmlURL: "https://github.com/macmixing/keyvox/releases/tag/v999.0.0",
                body: body,
                dmgURL: "https://github.com/macmixing/keyvox/releases/download/v999.0.0/KeyVox-999.0.0.dmg"
            )
            return (self.okResponse(), data)
        }

        let service = makeService(promptPresenter: promptPresenter, now: now, session: session, checkInterval: 60 * 60 * 24)
        service.checkForUpdatesIfNeeded()
        try await waitForCondition { promptPresenter.prompts.count == 1 }

        XCTAssertTrue(promptPresenter.prompts[0].message == "KeyVox v1.0.0 - Initial Public Release\nRelease date: March 1, 2026")
    }

    func testUpdatePromptFallsBackWhenSummarySanitizesToEmpty() async throws {
        let promptPresenter = RecordingPromptPresenter()
        let now = MutableNow(Date(timeIntervalSince1970: 1_700_000_000))
        let session = makeMockSession()

        MockURLProtocol.handler = { _ in
            let body = """
            ## Summary
            **
            __
            `

            ## Details
            Stable improvements shipped
            """
            let data = self.releaseData(
                tag: "999.0.0",
                htmlURL: "https://github.com/macmixing/keyvox/releases/tag/v999.0.0",
                body: body,
                dmgURL: "https://github.com/macmixing/keyvox/releases/download/v999.0.0/KeyVox-999.0.0.dmg"
            )
            return (self.okResponse(), data)
        }

        let service = makeService(promptPresenter: promptPresenter, now: now, session: session, checkInterval: 60 * 60 * 24)
        service.checkForUpdatesIfNeeded()
        try await waitForCondition { promptPresenter.prompts.count == 1 }

        XCTAssertTrue(promptPresenter.prompts[0].message == "Summary\nDetails\nStable improvements shipped")
    }

    func testUpdatePromptRespects240CharLimitWithEllipsis() async throws {
        let promptPresenter = RecordingPromptPresenter()
        let now = MutableNow(Date(timeIntervalSince1970: 1_700_000_000))
        let session = makeMockSession()

        MockURLProtocol.handler = { _ in
            let longLine = String(repeating: "A", count: 300)
            let data = self.releaseData(
                tag: "999.0.0",
                htmlURL: "https://github.com/macmixing/keyvox/releases/tag/v999.0.0",
                body: longLine,
                dmgURL: "https://github.com/macmixing/keyvox/releases/download/v999.0.0/KeyVox-999.0.0.dmg"
            )
            return (self.okResponse(), data)
        }

        let service = makeService(promptPresenter: promptPresenter, now: now, session: session, checkInterval: 60 * 60 * 24)
        service.checkForUpdatesIfNeeded()
        try await waitForCondition { promptPresenter.prompts.count == 1 }

        let message = promptPresenter.prompts[0].message
        XCTAssertTrue(message.count <= 240)
        XCTAssertTrue(message.hasSuffix("…"))
    }

    func testManualCheckShowsUnavailablePromptWhenFetchFails() async throws {
        let promptPresenter = RecordingPromptPresenter()
        let now = MutableNow(Date(timeIntervalSince1970: 1_700_000_000))
        let session = makeMockSession()

        MockURLProtocol.handler = { _ in
            let response = HTTPURLResponse(
                url: URL(string: "https://api.github.com/repos/macmixing/keyvox/releases/latest")!,
                statusCode: 404,
                httpVersion: nil,
                headerFields: nil
            )!
            return (response, Data())
        }

        let service = makeService(promptPresenter: promptPresenter, now: now, session: session, checkInterval: 60 * 60 * 24)
        service.checkForUpdatesManually()
        try await waitForCondition { promptPresenter.prompts.count == 1 }

        XCTAssertTrue(promptPresenter.prompts[0].title == "Updates Temporarily Unavailable")
        XCTAssertTrue(promptPresenter.prompts[0].primaryButtonTitle == nil)
        XCTAssertTrue(service.latestRemoteInfo == nil)
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
        let assets: [[String: String]]
        if let dmgURL {
            assets = [["name": "KeyVox.dmg", "browser_download_url": dmgURL]]
        } else {
            assets = []
        }

        let payload: [String: Any] = [
            "tag_name": tag,
            "body": body,
            "html_url": htmlURL,
            "assets": assets
        ]
        return try! JSONSerialization.data(withJSONObject: payload, options: [])
    }
}
