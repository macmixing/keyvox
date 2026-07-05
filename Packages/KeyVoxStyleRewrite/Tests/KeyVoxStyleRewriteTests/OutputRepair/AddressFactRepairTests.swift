import Foundation
import XCTest
@testable import KeyVoxStyleRewrite

final class AddressFactRepairTests: XCTestCase {
    func testRewriteRepairDoesNotConvertAddressLikeSpokenNumberClusters() {
        let output = OutputRepair.repairModelOutput(
            original: "Meet me at eleven fifty two North Washington Street.",
            rewritten: "Meet me at eleven fifty two North Washington Street."
        )

        XCTAssertEqual(output, "Meet me at eleven fifty two North Washington Street.")
    }

    func testRewriteRepairRestoresAddressNumberConvertedToTime() {
        let output = OutputRepair.repairModelOutput(
            original: "Meet me at 1152 North Washington Street.",
            rewritten: "Meet me at 11:52 North Washington Street."
        )

        XCTAssertEqual(output, "Meet me at 1152 North Washington Street.")
    }

    func testRewriteRepairRestoresSpokenAddressNumberCollapsedByModel() {
        let output = OutputRepair.repairModelOutput(
            original: "Yeah, my address is twelve fifty five North Washington Avenue.",
            rewritten: "Yeah, my address is 125 North Washington Avenue."
        )

        XCTAssertEqual(output, "Yeah, my address is 1255 North Washington Avenue.")
    }

    func testRewriteRepairRestoresDigitByDigitSpokenAddressNumberCollapsedByModel() {
        let output = OutputRepair.repairModelOutput(
            original: "Yeah, my address is one two five five North Washington Avenue.",
            rewritten: "Yeah, my address is 125 North Washington Avenue."
        )

        XCTAssertEqual(output, "Yeah, my address is 1255 North Washington Avenue.")
    }

    func testRewriteRepairRestoresTimeShapedAddressBeforeOrdinalStreet() {
        let output = OutputRepair.repairModelOutput(
            original: "Meet me at seven fifty nine 7th Street.",
            rewritten: "Meet me at 7:59 7th Street."
        )

        XCTAssertEqual(output, "Meet me at 759 7th Street.")
    }

    func testRewriteRepairRestoresTimeShapedAddressAndOrdinalStreetDrift() {
        let output = OutputRepair.repairModelOutput(
            original: "She said her address was eleven thirty seven North Twelfth Street.",
            rewritten: "She said her address was 11:37 North 2nd Street."
        )

        XCTAssertEqual(output, "She said her address was 1137 North 12th Street.")
    }

    func testRewriteRepairRestoresAddressNumberWithDifferentStreetNames() {
        let output = OutputRepair.repairModelOutput(
            original: "Send it to sixteen fifty nine Whitton Avenue and then 2359 North 59th Drive.",
            rewritten: "Send it to 16:59 Whitton Avenue and then 23:59 North 59th Drive."
        )

        XCTAssertEqual(output, "Send it to 1659 Whitton Avenue and then 2359 North 59th Drive.")
    }

    func testRewriteRepairRestoresOrdinalStreetNumberDriftInAddressSuffix() {
        let output = OutputRepair.repairModelOutput(
            original: "Yeah, she said her address was eleven thirty seven North Twelfth Street.",
            rewritten: "She said her address was 1137 North 2nd Street."
        )

        XCTAssertEqual(output, "She said her address was 1137 North 12th Street.")
    }

    func testRewriteRepairCanonicalizesSpokenOrdinalStreetSuffix() {
        let output = OutputRepair.repairModelOutput(
            original: "She said her address was eleven twenty five North Twelfth Street.",
            rewritten: "She said her address was 1125 North Twelfth Street."
        )

        XCTAssertEqual(output, "She said her address was 1125 North 12th Street.")
    }

    func testRewriteRepairRestoresCollapsedAddressNumberAndOrdinalStreetSuffix() {
        let output = OutputRepair.repairModelOutput(
            original: "She said her address was eleven twenty five North Twelfth Street.",
            rewritten: "She said her address was 125 North 2nd Street."
        )

        XCTAssertEqual(output, "She said her address was 1125 North 12th Street.")
    }

    func testRewriteRepairRestoresDifferentOrdinalStreetNumberDriftInAddressSuffix() {
        let output = OutputRepair.repairModelOutput(
            original: "Mail it to twenty three fifty nine West Fifty Ninth Drive.",
            rewritten: "Mail it to 2359 West 9th Drive."
        )

        XCTAssertEqual(output, "Mail it to 2359 West 59th Drive.")
    }

    func testRewriteRepairRestoresCommonOrdinalStreetNumberDriftInAddressSuffixes() {
        let cases = [
            (
                original: "Meet me at eight thirty seven North Seventh Street.",
                rewritten: "Meet me at 837 North 2nd Street.",
                repaired: "Meet me at 837 North 7th Street."
            ),
            (
                original: "Meet me at nine forty eight South Eighth Avenue.",
                rewritten: "Meet me at 948 South 1st Avenue.",
                repaired: "Meet me at 948 South 8th Avenue."
            ),
            (
                original: "Meet me at ten fifty nine West Ninth Drive.",
                rewritten: "Meet me at 1059 West 5th Drive.",
                repaired: "Meet me at 1059 West 9th Drive."
            ),
        ]

        for testCase in cases {
            let output = OutputRepair.repairModelOutput(
                original: testCase.original,
                rewritten: testCase.rewritten
            )

            XCTAssertEqual(output, testCase.repaired)
        }
    }
}
