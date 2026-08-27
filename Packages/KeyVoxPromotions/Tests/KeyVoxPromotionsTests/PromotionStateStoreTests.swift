import Foundation
import XCTest
@testable import KeyVoxPromotions

final class PromotionStateStoreTests: XCTestCase {
    func testProductionAndPreviewNamespacesRemainIndependent() throws {
        let suiteName = "KeyVoxPromotionsTests.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let productionStore = PromotionStateStore(defaults: defaults, namespace: "Production")
        let previewStore = PromotionStateStore(defaults: defaults, namespace: "Preview")
        let productionState = PromotionSelectionState(
            campaignID: "production",
            selectedAt: Date(timeIntervalSince1970: 100)
        )
        let previewState = PromotionSelectionState(
            campaignID: "preview",
            selectedAt: Date(timeIntervalSince1970: 200)
        )

        productionStore.setSelectionState(productionState)
        previewStore.setSelectionState(previewState)

        XCTAssertEqual(productionStore.selectionState(), productionState)
        XCTAssertEqual(previewStore.selectionState(), previewState)
    }
}
