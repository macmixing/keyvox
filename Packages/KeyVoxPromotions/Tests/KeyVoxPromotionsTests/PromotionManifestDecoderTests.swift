import Foundation
import XCTest
@testable import KeyVoxPromotions

final class PromotionManifestDecoderTests: XCTestCase {
    func testBundledManifestIsValidAndContainsEachPlatformCampaign() throws {
        let manifest = try PromotionManifestDecoder.decode(
            PromotionManifestRepository.bundledManifestData()
        )

        XCTAssertEqual(manifest.schemaVersion, 1)
        XCTAssertEqual(manifest.selection, PromotionSelectionPolicy(mode: .rotating, intervalHours: 72))
        XCTAssertTrue(manifest.campaigns.contains { campaign in
            campaign.id == "ios-compact-keys"
                && campaign.targets.contains { $0.platform == .iOS }
        })
        XCTAssertTrue(manifest.campaigns.contains { campaign in
            campaign.id == "macos-keyvox-for-iphone"
                && campaign.targets.contains { $0.platform == .macOS }
        })
    }

    func testRejectsDuplicateCampaignIDs() {
        let campaign = makeCampaign(id: "duplicate")
        let manifest = PromotionManifest(
            selection: PromotionSelectionPolicy(mode: .static),
            campaigns: [campaign, campaign]
        )

        XCTAssertThrowsError(try PromotionManifestDecoder.validate(manifest)) { error in
            XCTAssertEqual(error as? PromotionManifestError, .duplicateCampaignID("duplicate"))
        }
    }

    func testRejectsNonHTTPSActionURL() {
        let campaign = PromotionCampaign(
            id: "bad-url",
            targets: [PromotionTarget(platform: .iOS)],
            icon: PromotionIcon(kind: .systemImage, name: "star"),
            title: "Title",
            message: "Message",
            buttonTitle: "Open",
            action: PromotionAction(url: URL(string: "http://example.com")!)
        )
        let manifest = PromotionManifest(
            selection: PromotionSelectionPolicy(mode: .static),
            campaigns: [campaign]
        )

        XCTAssertThrowsError(try PromotionManifestDecoder.validate(manifest)) { error in
            XCTAssertEqual(error as? PromotionManifestError, .invalidURL("bad-url"))
        }
    }

    private func makeCampaign(id: String) -> PromotionCampaign {
        PromotionCampaign(
            id: id,
            targets: [PromotionTarget(platform: .iOS)],
            icon: PromotionIcon(kind: .systemImage, name: "star"),
            title: "Title",
            message: "Message"
        )
    }
}
