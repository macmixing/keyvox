import Combine
import Testing
@testable import KeyVox_iOS

@MainActor
struct KeyVoxSessionLiveActivityCoordinatorTests {
    @Test func startsActivityWhenSessionBecomesEnabled() async {
        let controller = MockKeyVoxSessionLiveActivityController()
        let coordinator = makeCoordinator(controller: controller)

        await coordinator.applyState(
            isSessionActive: true,
            sessionDisablePending: false,
            weeklyWordCount: 128
        )

        #expect(controller.startedOrUpdatedWordCounts == [128])
        #expect(controller.endCallCount == 0)
    }

    @Test func endsActivityWhenDisablePendingBecomesTrue() async {
        let controller = MockKeyVoxSessionLiveActivityController()
        let coordinator = makeCoordinator(controller: controller)

        await coordinator.applyState(
            isSessionActive: true,
            sessionDisablePending: false,
            weeklyWordCount: 128
        )
        await coordinator.applyState(
            isSessionActive: true,
            sessionDisablePending: true,
            weeklyWordCount: 128
        )

        #expect(controller.startedOrUpdatedWordCounts == [128])
        #expect(controller.endCallCount == 1)
    }

    @Test func updatesWeeklyWordCountWhileActivityIsVisible() async {
        let controller = MockKeyVoxSessionLiveActivityController()
        let coordinator = makeCoordinator(controller: controller)

        await coordinator.applyState(
            isSessionActive: true,
            sessionDisablePending: false,
            weeklyWordCount: 128
        )
        await coordinator.applyState(
            isSessionActive: true,
            sessionDisablePending: false,
            weeklyWordCount: 512
        )

        #expect(controller.startedOrUpdatedWordCounts == [128, 512])
    }

    @Test func endsExistingActivityOnInitializationWhenSessionIsInactive() async {
        let controller = MockKeyVoxSessionLiveActivityController(isActivityActive: true)
        _ = makeCoordinator(
            initialIsSessionActive: false,
            initialSessionDisablePending: false,
            initialWeeklyWordCount: 42,
            controller: controller
        )

        await Task.yield()

        #expect(controller.endCallCount == 1)
    }

    private func makeCoordinator(
        initialIsSessionActive: Bool = false,
        initialSessionDisablePending: Bool = false,
        initialWeeklyWordCount: Int = 0,
        controller: MockKeyVoxSessionLiveActivityController
    ) -> KeyVoxSessionLiveActivityCoordinator {
        KeyVoxSessionLiveActivityCoordinator(
            initialIsSessionActive: initialIsSessionActive,
            initialSessionDisablePending: initialSessionDisablePending,
            initialWeeklyWordCount: initialWeeklyWordCount,
            isSessionActivePublisher: Empty().eraseToAnyPublisher(),
            sessionDisablePendingPublisher: Empty().eraseToAnyPublisher(),
            weeklyWordCountPublisher: Empty().eraseToAnyPublisher(),
            liveActivityController: controller
        )
    }
}

@MainActor
private final class MockKeyVoxSessionLiveActivityController: KeyVoxSessionLiveActivityControlling {
    var isActivityActive: Bool
    var startedOrUpdatedWordCounts: [Int] = []
    var endCallCount = 0

    init(isActivityActive: Bool = false) {
        self.isActivityActive = isActivityActive
    }

    func startOrUpdate(weeklyWordCount: Int) async {
        isActivityActive = true
        startedOrUpdatedWordCounts.append(weeklyWordCount)
    }

    func end() async {
        isActivityActive = false
        endCallCount += 1
    }
}
