import Foundation
import XCTest
@testable import KeyVoxPromotions

final class PromotionSelectionTests: XCTestCase {
    private let now = Date(timeIntervalSince1970: 1_000_000)
    private let audience = PromotionAudience(platform: .iOS, appVersion: "1.4.0")

    func testSelectsFirstEligibleCampaignAndKeepsItWithinInterval() {
        let manifest = makeManifest()

        let initial = PromotionSelector.select(
            manifest: manifest,
            audience: audience,
            now: now,
            previousState: nil,
            previewCampaignID: nil
        )
        let retained = PromotionSelector.select(
            manifest: manifest,
            audience: audience,
            now: now.addingTimeInterval(71 * 60 * 60),
            previousState: initial.state,
            previewCampaignID: nil
        )

        XCTAssertEqual(initial.campaign?.id, "first")
        XCTAssertEqual(retained.campaign?.id, "first")
        XCTAssertEqual(retained.state, initial.state)
    }

    func testAdvancesInManifestOrderAfterInterval() {
        let manifest = makeManifest()
        let previousState = PromotionSelectionState(campaignID: "first", selectedAt: now)

        let selection = PromotionSelector.select(
            manifest: manifest,
            audience: audience,
            now: now.addingTimeInterval(72 * 60 * 60),
            previousState: previousState,
            previewCampaignID: nil
        )

        XCTAssertEqual(selection.campaign?.id, "second")
        XCTAssertEqual(selection.state?.selectedAt, now.addingTimeInterval(72 * 60 * 60))
    }

    func testPreviewIDBypassesDateAndMinimumVersionButNotPlatform() {
        let unavailable = PromotionCampaign(
            id: "future-ios",
            targets: [PromotionTarget(platform: .iOS, minimumAppVersion: "99.0.0")],
            icon: PromotionIcon(kind: .systemImage, name: "star"),
            title: "Future",
            message: "Future",
            startsAt: now.addingTimeInterval(10_000)
        )
        let wrongPlatform = PromotionCampaign(
            id: "mac-only",
            targets: [PromotionTarget(platform: .macOS)],
            icon: PromotionIcon(kind: .systemImage, name: "star"),
            title: "Mac",
            message: "Mac"
        )
        let manifest = PromotionManifest(
            selection: PromotionSelectionPolicy(mode: .static),
            campaigns: [unavailable, wrongPlatform]
        )

        let preview = PromotionSelector.select(
            manifest: manifest,
            audience: audience,
            now: now,
            previousState: nil,
            previewCampaignID: "future-ios"
        )
        let wrongPlatformPreview = PromotionSelector.select(
            manifest: manifest,
            audience: audience,
            now: now,
            previousState: nil,
            previewCampaignID: "mac-only"
        )

        XCTAssertEqual(preview.campaign?.id, "future-ios")
        XCTAssertNil(wrongPlatformPreview.campaign)
    }

    func testFiltersDatesVersionsAndPlatforms() {
        let manifest = PromotionManifest(
            selection: PromotionSelectionPolicy(mode: .static),
            campaigns: [
                makeCampaign(id: "mac", platform: .macOS),
                makeCampaign(id: "newer", minimumAppVersion: "1.4.1"),
                makeCampaign(id: "eligible", minimumAppVersion: "1.4"),
            ]
        )

        let selection = PromotionSelector.select(
            manifest: manifest,
            audience: audience,
            now: now,
            previousState: nil,
            previewCampaignID: nil
        )

        XCTAssertEqual(selection.campaign?.id, "eligible")
    }

    private func makeManifest() -> PromotionManifest {
        PromotionManifest(
            selection: PromotionSelectionPolicy(mode: .rotating, intervalHours: 72),
            campaigns: [makeCampaign(id: "first"), makeCampaign(id: "second")]
        )
    }

    private func makeCampaign(
        id: String,
        platform: PromotionPlatform = .iOS,
        minimumAppVersion: String? = nil
    ) -> PromotionCampaign {
        PromotionCampaign(
            id: id,
            targets: [PromotionTarget(platform: platform, minimumAppVersion: minimumAppVersion)],
            icon: PromotionIcon(kind: .systemImage, name: "star"),
            title: id,
            message: id
        )
    }
}
