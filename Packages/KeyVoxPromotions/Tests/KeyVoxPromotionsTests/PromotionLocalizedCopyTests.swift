import Foundation
import XCTest
@testable import KeyVoxPromotions

final class PromotionLocalizedCopyTests: XCTestCase {
    private let base = PromotionLocalizedCopy(title: "Base title", message: "Base message", buttonTitle: "Base button", sharingTitle: "Base share")
    private let german = PromotionLocalizedCopy(title: "German title", message: "German message", buttonTitle: "German button", sharingTitle: "German share")

    func testUsesExactLanguageMatch() {
        let copy = makeCampaign(localizations: ["de": german]).copy(forLanguage: "de")

        XCTAssertEqual(copy, PromotionCopy(title: german.title, message: german.message, buttonTitle: german.buttonTitle, sharingTitle: german.sharingTitle))
    }

    func testFallsBackFromRegionalVariantToBaseLanguage() {
        let campaign = makeCampaign(localizations: ["de": german])

        XCTAssertEqual(campaign.copy(forLanguage: "de-AT").title, german.title)
        XCTAssertEqual(campaign.copy(forLanguage: "de_CH").title, german.title)
    }

    func testFallsBackToBaseCopyWithoutMatchingLanguage() {
        let campaign = makeCampaign(localizations: ["de": german])

        XCTAssertEqual(campaign.copy(forLanguage: "it"), baseCopy())
        XCTAssertEqual(campaign.copy(forLanguage: nil), baseCopy())
        XCTAssertEqual(makeCampaign(localizations: nil).copy(forLanguage: "de"), baseCopy())
    }

    func testMissingLocalizedButtonAndShareTitlesFallBackToBase() {
        let partial = PromotionLocalizedCopy(title: german.title, message: german.message)
        let copy = makeCampaign(localizations: ["de": partial]).copy(forLanguage: "de")

        XCTAssertEqual(copy.title, german.title)
        XCTAssertEqual(copy.buttonTitle, base.buttonTitle)
        XCTAssertEqual(copy.sharingTitle, base.sharingTitle)
    }

    func testDecodesManifestWithAndWithoutLocalizations() throws {
        let json = """
        {
          "schemaVersion": 1,
          "selection": { "mode": "static" },
          "campaigns": [
            {
              "id": "with-localizations",
              "targets": [{ "platform": "ios" }],
              "icon": { "kind": "systemImage", "name": "star" },
              "title": "Base title",
              "message": "Base message",
              "localizations": { "de": { "title": "German title", "message": "German message" } }
            },
            {
              "id": "without-localizations",
              "targets": [{ "platform": "ios" }],
              "icon": { "kind": "systemImage", "name": "star" },
              "title": "Base title",
              "message": "Base message"
            }
          ]
        }
        """
        let manifest = try PromotionManifestDecoder.decode(Data(json.utf8))

        XCTAssertEqual(manifest.campaigns[0].copy(forLanguage: "de").message, german.message)
        XCTAssertNil(manifest.campaigns[1].localizations)
        XCTAssertEqual(manifest.campaigns[1].copy(forLanguage: "de").message, base.message)
    }

    func testRejectsEmptyLocalizedCopy() {
        let empty = PromotionLocalizedCopy(title: " ", message: german.message)

        assertInvalidCopy(makeCampaign(localizations: ["de": empty]))
    }

    func testRejectsLocalizedButtonWithoutAction() {
        let campaign = PromotionCampaign(
            id: "campaign",
            targets: [PromotionTarget(platform: .iOS)],
            icon: PromotionIcon(kind: .systemImage, name: "star"),
            title: base.title,
            message: base.message,
            localizations: ["de": PromotionLocalizedCopy(title: german.title, message: german.message, buttonTitle: german.buttonTitle)]
        )

        assertInvalidCopy(campaign)
    }

    private func baseCopy() -> PromotionCopy {
        PromotionCopy(title: base.title, message: base.message, buttonTitle: base.buttonTitle, sharingTitle: base.sharingTitle)
    }

    private func makeCampaign(localizations: [String: PromotionLocalizedCopy]?) -> PromotionCampaign {
        PromotionCampaign(
            id: "campaign",
            targets: [PromotionTarget(platform: .iOS)],
            icon: PromotionIcon(kind: .systemImage, name: "star"),
            title: base.title,
            message: base.message,
            buttonTitle: base.buttonTitle,
            action: PromotionAction(url: URL(string: "https://example.com")!),
            sharing: PromotionSharing(url: URL(string: "https://example.com/share")!, title: base.sharingTitle),
            localizations: localizations
        )
    }

    private func assertInvalidCopy(_ campaign: PromotionCampaign, file: StaticString = #filePath, line: UInt = #line) {
        let manifest = PromotionManifest(selection: PromotionSelectionPolicy(mode: .static), campaigns: [campaign])

        XCTAssertThrowsError(try PromotionManifestDecoder.validate(manifest), file: file, line: line) { error in
            XCTAssertEqual(error as? PromotionManifestError, .invalidCopy("campaign"), file: file, line: line)
        }
    }
}
