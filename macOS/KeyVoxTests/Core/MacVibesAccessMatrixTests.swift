import XCTest
import KeyVoxStyleRewrite
@testable import KeyVox

@MainActor
final class MacVibesAccessMatrixTests: XCTestCase {
    func testNotInstalledShowsDownloadControl() {
        let matrix = resolve(modelState: .notInstalled)

        XCTAssertEqual(matrix.mainCardContent, .downloadRequired)
        XCTAssertEqual(matrix.cardControl, .download)
        XCTAssertEqual(matrix.cardAction, .downloadModel)
        XCTAssertFalse(matrix.showsVibeSelector)
        XCTAssertEqual(matrix.displayedSelectedVibe, .none)
        XCTAssertNil(matrix.progress)
        XCTAssertNil(matrix.errorMessage)
    }

    func testDownloadingShowsProgressControl() {
        let matrix = resolve(modelState: .downloading(progress: 0.42))

        XCTAssertEqual(matrix.mainCardContent, .downloading)
        XCTAssertEqual(matrix.cardControl, .progress)
        XCTAssertEqual(matrix.cardAction, .none)
        XCTAssertFalse(matrix.showsVibeSelector)
        XCTAssertEqual(matrix.progress, 0.42)
    }

    func testInstallingShowsProgressControl() {
        let matrix = resolve(modelState: .installing(progress: 0.96))

        XCTAssertEqual(matrix.mainCardContent, .installing)
        XCTAssertEqual(matrix.cardControl, .progress)
        XCTAssertEqual(matrix.cardAction, .none)
        XCTAssertFalse(matrix.showsVibeSelector)
        XCTAssertEqual(matrix.progress, 0.96)
    }

    func testFailedShowsRepairControl() {
        let matrix = resolve(modelState: .failed(message: "bad hash"))

        XCTAssertEqual(matrix.mainCardContent, .installFailed)
        XCTAssertEqual(matrix.cardControl, .repair)
        XCTAssertEqual(matrix.cardAction, .repairModel)
        XCTAssertFalse(matrix.showsVibeSelector)
        XCTAssertEqual(matrix.errorMessage, "bad hash")
    }

    func testReadyShowsVibeSelector() {
        let matrix = resolve(modelState: .ready, selectedVibe: .chill)

        XCTAssertEqual(matrix.mainCardContent, .selectedVibe(.chill))
        XCTAssertEqual(matrix.cardControl, .change)
        XCTAssertEqual(matrix.cardAction, .openVibeSelector)
        XCTAssertTrue(matrix.showsVibeSelector)
        XCTAssertEqual(matrix.displayedSelectedVibe, .chill)
        XCTAssertNil(matrix.progress)
        XCTAssertNil(matrix.errorMessage)
    }

    func testModelStateMapsInstallState() {
        XCTAssertEqual(MacVibesAccessMatrix.modelState(from: .notInstalled), .notInstalled)
        XCTAssertEqual(MacVibesAccessMatrix.modelState(from: .downloading(progress: 0.2)), .downloading(progress: 0.2))
        XCTAssertEqual(MacVibesAccessMatrix.modelState(from: .installing(progress: 0.9)), .installing(progress: 0.9))
        XCTAssertEqual(MacVibesAccessMatrix.modelState(from: .failed(message: "failed")), .failed(message: "failed"))
        XCTAssertEqual(MacVibesAccessMatrix.modelState(from: .ready), .ready)
    }

    private func resolve(
        modelState: MacVibesAccessMatrix.ModelState,
        selectedVibe: StyleRewriteStyle = .casual
    ) -> MacVibesAccessMatrix {
        MacVibesAccessMatrix.resolve(modelState: modelState, selectedVibe: selectedVibe)
    }
}
