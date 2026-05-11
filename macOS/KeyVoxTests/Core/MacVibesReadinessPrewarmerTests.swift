import Combine
import KeyVoxStyleRewrite
import XCTest
@testable import KeyVox

@MainActor
final class MacVibesReadinessPrewarmerTests: XCTestCase {
    func testReadyModelOnStartupPrewarmsCasualVibe() {
        let installState = CurrentValueSubject<MacLocalRewriteModelInstallState, Never>(.ready)
        var prewarmedStyles: [StyleRewriteStyle] = []

        let prewarmer = MacVibesReadinessPrewarmer(
            installState: installState.eraseToAnyPublisher(),
            prewarm: { prewarmedStyles.append($0) }
        )

        XCTAssertNotNil(prewarmer)
        XCTAssertEqual(prewarmedStyles, [.casual])
    }

    func testDownloadTransitionToReadyPrewarmsCasualVibe() {
        let installState = CurrentValueSubject<MacLocalRewriteModelInstallState, Never>(.notInstalled)
        var prewarmedStyles: [StyleRewriteStyle] = []

        let prewarmer = MacVibesReadinessPrewarmer(
            installState: installState.eraseToAnyPublisher(),
            prewarm: { prewarmedStyles.append($0) }
        )

        installState.send(.downloading(progress: 0.25))
        installState.send(.installing(progress: 0.96))
        installState.send(.ready)

        XCTAssertNotNil(prewarmer)
        XCTAssertEqual(prewarmedStyles, [.casual])
    }

    func testRepeatedReadyStatePrewarmsCurrentModelOnce() {
        let installState = CurrentValueSubject<MacLocalRewriteModelInstallState, Never>(.ready)
        var prewarmedStyles: [StyleRewriteStyle] = []

        let prewarmer = MacVibesReadinessPrewarmer(
            installState: installState.eraseToAnyPublisher(),
            prewarm: { prewarmedStyles.append($0) }
        )

        installState.send(.ready)
        installState.send(.ready)

        XCTAssertNotNil(prewarmer)
        XCTAssertEqual(prewarmedStyles, [.casual])
    }

    func testReadinessResetAllowsCasualVibeToPrewarmAfterReinstall() {
        let installState = CurrentValueSubject<MacLocalRewriteModelInstallState, Never>(.ready)
        var prewarmedStyles: [StyleRewriteStyle] = []

        let prewarmer = MacVibesReadinessPrewarmer(
            installState: installState.eraseToAnyPublisher(),
            prewarm: { prewarmedStyles.append($0) }
        )

        installState.send(.notInstalled)
        installState.send(.ready)

        XCTAssertNotNil(prewarmer)
        XCTAssertEqual(prewarmedStyles, [.casual, .casual])
    }
}
