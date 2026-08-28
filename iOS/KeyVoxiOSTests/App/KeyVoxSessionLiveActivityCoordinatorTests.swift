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
            liveActivitiesEnabled: true,
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
            liveActivitiesEnabled: true,
            weeklyWordCount: 128
        )
        await coordinator.applyState(
            isSessionActive: true,
            sessionDisablePending: true,
            liveActivitiesEnabled: true,
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
            liveActivitiesEnabled: true,
            weeklyWordCount: 128
        )
        await coordinator.applyState(
            isSessionActive: true,
            sessionDisablePending: false,
            liveActivitiesEnabled: true,
            weeklyWordCount: 512
        )

        #expect(controller.startedOrUpdatedWordCounts == [128, 512])
    }

    @Test func endsExistingActivityOnInitializationWhenSessionIsInactive() async {
        let controller = MockKeyVoxSessionLiveActivityController(isActivityActive: true)
        _ = makeCoordinator(
            initialIsSessionActive: false,
            initialSessionDisablePending: false,
            initialLiveActivitiesEnabled: true,
            initialWeeklyWordCount: 42,
            controller: controller
        )

        await Task.yield()

        #expect(controller.endCallCount == 1)
    }

    @Test func doesNotStartActivityWhenLiveActivitiesAreDisabled() async {
        let controller = MockKeyVoxSessionLiveActivityController()
        let coordinator = makeCoordinator(controller: controller)

        await coordinator.applyState(
            isSessionActive: true,
            sessionDisablePending: false,
            liveActivitiesEnabled: false,
            weeklyWordCount: 128
        )

        #expect(controller.startedOrUpdatedWordCounts.isEmpty)
        #expect(controller.endCallCount == 0)
    }

    @Test func endsExistingActivityWhenLiveActivitiesAreDisabled() async {
        let controller = MockKeyVoxSessionLiveActivityController()
        let coordinator = makeCoordinator(controller: controller)

        await coordinator.applyState(
            isSessionActive: true,
            sessionDisablePending: false,
            liveActivitiesEnabled: true,
            weeklyWordCount: 128
        )
        await coordinator.applyState(
            isSessionActive: true,
            sessionDisablePending: false,
            liveActivitiesEnabled: false,
            weeklyWordCount: 128
        )

        #expect(controller.startedOrUpdatedWordCounts == [128])
        #expect(controller.endCallCount == 1)
    }

    @Test func preparesActivityBeforeRecordingSessionBecomesActive() async throws {
        let controller = MockKeyVoxSessionLiveActivityController()
        let coordinator = makeCoordinator(controller: controller)
        await Task.yield()

        try await coordinator.prepareForAudioRecordingIntent()

        #expect(controller.startedOrUpdatedWordCounts == [0])
        #expect(controller.isActivityActive)
    }

    @Test func refusesPreparationWhenLiveActivitiesAreDisabled() async {
        let controller = MockKeyVoxSessionLiveActivityController()
        let coordinator = makeCoordinator(
            initialLiveActivitiesEnabled: false,
            controller: controller
        )
        await Task.yield()

        var didThrow = false
        do {
            try await coordinator.prepareForAudioRecordingIntent()
        } catch {
            didThrow = true
        }

        #expect(didThrow)
        #expect(controller.startedOrUpdatedWordCounts.isEmpty)
    }

    @Test func failedPreparationClearsStartupReservation() async {
        let controller = MockKeyVoxSessionLiveActivityController(startError: TestLiveActivityError.requestFailed)
        let coordinator = makeCoordinator(controller: controller)
        await Task.yield()

        do {
            try await coordinator.prepareForAudioRecordingIntent()
        } catch {
            // Expected: the explicit preparation path propagates ActivityKit failures.
        }
        controller.startError = nil
        await coordinator.applyState(
            isSessionActive: false,
            sessionDisablePending: false,
            liveActivitiesEnabled: true,
            weeklyWordCount: 0
        )

        #expect(controller.startAttemptCount == 1)
        #expect(controller.startedOrUpdatedWordCounts.isEmpty)
    }

    @Test func failedRecordingStartRollsBackPreparedActivity() async throws {
        let controller = MockKeyVoxSessionLiveActivityController()
        let coordinator = makeCoordinator(controller: controller)
        await Task.yield()

        try await coordinator.prepareForAudioRecordingIntent()
        await coordinator.completeAudioRecordingIntentStart(
            isSessionActive: false,
            sessionDisablePending: false
        )

        #expect(controller.endCallCount == 1)
        #expect(!controller.isActivityActive)
    }

    @Test func inactiveReconciliationDoesNotEndPreparedActivity() async throws {
        let controller = MockKeyVoxSessionLiveActivityController()
        let coordinator = makeCoordinator(controller: controller)
        await Task.yield()

        try await coordinator.prepareForAudioRecordingIntent()
        await coordinator.applyState(
            isSessionActive: false,
            sessionDisablePending: false,
            liveActivitiesEnabled: true,
            weeklyWordCount: 0
        )

        #expect(controller.endCallCount == 0)
        #expect(controller.isActivityActive)
    }

    @Test func successfulRecordingStartKeepsPreparedActivity() async throws {
        let controller = MockKeyVoxSessionLiveActivityController()
        let coordinator = makeCoordinator(controller: controller)
        await Task.yield()

        try await coordinator.prepareForAudioRecordingIntent()
        await coordinator.completeAudioRecordingIntentStart(
            isSessionActive: true,
            sessionDisablePending: false
        )

        #expect(controller.endCallCount == 0)
        #expect(controller.isActivityActive)
    }

    private func makeCoordinator(
        initialIsSessionActive: Bool = false,
        initialSessionDisablePending: Bool = false,
        initialLiveActivitiesEnabled: Bool = true,
        initialWeeklyWordCount: Int = 0,
        controller: MockKeyVoxSessionLiveActivityController
    ) -> KeyVoxSessionLiveActivityCoordinator {
        KeyVoxSessionLiveActivityCoordinator(
            initialIsSessionActive: initialIsSessionActive,
            initialSessionDisablePending: initialSessionDisablePending,
            initialLiveActivitiesEnabled: initialLiveActivitiesEnabled,
            initialWeeklyWordCount: initialWeeklyWordCount,
            isSessionActivePublisher: Empty().eraseToAnyPublisher(),
            sessionDisablePendingPublisher: Empty().eraseToAnyPublisher(),
            liveActivitiesEnabledPublisher: Empty().eraseToAnyPublisher(),
            weeklyWordCountPublisher: Empty().eraseToAnyPublisher(),
            liveActivityController: controller
        )
    }
}

@MainActor
private final class MockKeyVoxSessionLiveActivityController: KeyVoxSessionLiveActivityControlling {
    var isActivityActive: Bool
    var startedOrUpdatedWordCounts: [Int] = []
    var startAttemptCount = 0
    var startError: Error?
    var endCallCount = 0

    init(isActivityActive: Bool = false, startError: Error? = nil) {
        self.isActivityActive = isActivityActive
        self.startError = startError
    }

    func startOrUpdate(weeklyWordCount: Int) async throws {
        startAttemptCount += 1
        if let startError {
            throw startError
        }
        isActivityActive = true
        startedOrUpdatedWordCounts.append(weeklyWordCount)
    }

    func end() async {
        isActivityActive = false
        endCallCount += 1
    }
}

private enum TestLiveActivityError: Error {
    case requestFailed
}
