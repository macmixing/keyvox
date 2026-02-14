import Foundation
import Testing
@testable import KeyVox

@Suite(.serialized)
@MainActor
struct AppUpdateServiceTests {
    @Test
    func manualCheckShowsNoUpdatePromptWhenRemoteNotNewer() async throws {
        let promptPresenter = RecordingPromptPresenter()
        let now = MutableNow(Date(timeIntervalSince1970: 1_700_000_000))
        let session = makeMockSession()

        MockURLProtocol.handler = { _ in
            let data = releaseData(tag: "0.0.0", htmlURL: "https://github.com/macmixing/keyvox/releases/tag/v0.0.0", body: "No update")
            return (okResponse(), data)
        }

        let service = makeService(promptPresenter: promptPresenter, now: now, session: session, checkInterval: 60 * 60 * 24)
        service.checkForUpdatesManually()
        try await waitForCondition { promptPresenter.prompts.count == 1 }

        #expect(promptPresenter.prompts[0].title == "You're Up to Date")
        #expect(service.latestRemoteInfo?.version == "0.0.0")
    }

    @Test
    func autoCheckShowsUpdatePromptForNewerVersion() async throws {
        let promptPresenter = RecordingPromptPresenter()
        let now = MutableNow(Date(timeIntervalSince1970: 1_700_000_000))
        let session = makeMockSession()

        MockURLProtocol.handler = { _ in
            let data = releaseData(
                tag: "999.0.0",
                htmlURL: "https://github.com/macmixing/keyvox/releases/tag/v999.0.0",
                body: "Major release",
                dmgURL: "https://github.com/macmixing/keyvox/releases/download/v999.0.0/KeyVox-999.0.0.dmg"
            )
            return (okResponse(), data)
        }

        let service = makeService(promptPresenter: promptPresenter, now: now, session: session, checkInterval: 60 * 60 * 24)
        service.checkForUpdatesIfNeeded()
        try await waitForCondition { promptPresenter.prompts.count == 1 }

        #expect(promptPresenter.prompts[0].title == "KeyVox Update Available")
        #expect(service.latestRemoteInfo?.version == "999.0.0")
    }

    @Test
    func checkSkipsPromptWhenUpdateUrlHostNotAllowlisted() async throws {
        let promptPresenter = RecordingPromptPresenter()
        let now = MutableNow(Date(timeIntervalSince1970: 1_700_000_000))
        let session = makeMockSession()

        MockURLProtocol.handler = { _ in
            let data = releaseData(tag: "999.0.0", htmlURL: "https://evil.example.com/releases/v999", body: "Bad host")
            return (okResponse(), data)
        }

        let service = makeService(promptPresenter: promptPresenter, now: now, session: session, checkInterval: 60 * 60 * 24)
        service.checkForUpdatesIfNeeded()
        try await Task.sleep(nanoseconds: 200_000_000)

        #expect(promptPresenter.prompts.isEmpty)
        #expect(service.latestRemoteInfo == nil)
    }

    @Test
    func autoPromptCooldownIsPerLaunchAndIntervalBounded() async throws {
        let promptPresenter = RecordingPromptPresenter()
        let now = MutableNow(Date(timeIntervalSince1970: 1_700_000_000))
        let session = makeMockSession()

        MockURLProtocol.handler = { _ in
            let data = releaseData(
                tag: "999.0.0",
                htmlURL: "https://github.com/macmixing/keyvox/releases/tag/v999.0.0",
                body: "Major release",
                dmgURL: "https://github.com/macmixing/keyvox/releases/download/v999.0.0/KeyVox-999.0.0.dmg"
            )
            return (okResponse(), data)
        }

        let service = makeService(promptPresenter: promptPresenter, now: now, session: session, checkInterval: 5)

        service.checkForUpdatesIfNeeded()
        try await waitForCondition { promptPresenter.prompts.count == 1 }

        promptPresenter.prompts[0].onDismiss()

        service.checkForUpdatesIfNeeded()
        try await Task.sleep(nanoseconds: 200_000_000)
        #expect(promptPresenter.prompts.count == 1)

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
