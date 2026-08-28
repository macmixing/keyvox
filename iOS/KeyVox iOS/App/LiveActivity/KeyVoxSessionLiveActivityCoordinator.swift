import ActivityKit
import Combine
import Foundation

@MainActor
protocol KeyVoxSessionLiveActivityControlling {
    var isActivityActive: Bool { get }
    func startOrUpdate(weeklyWordCount: Int) async throws
    func end() async
}

@MainActor
final class KeyVoxSessionLiveActivityController: KeyVoxSessionLiveActivityControlling {
    private var activity: Activity<KeyVoxSessionLiveActivityAttributes>?
    private var lastWeeklyWordCount: Int?

    init() {
        activity = Activity<KeyVoxSessionLiveActivityAttributes>.activities.first
    }

    var isActivityActive: Bool {
        currentActivity != nil
    }

    func startOrUpdate(weeklyWordCount: Int) async throws {
        if let activity = currentActivity {
            guard lastWeeklyWordCount != weeklyWordCount else { return }

            await activity.update(
                ActivityContent(
                    state: .init(weeklyWordCount: weeklyWordCount),
                    staleDate: nil
                )
            )
            lastWeeklyWordCount = weeklyWordCount
            return
        }

        let activity = try Activity.request(
            attributes: KeyVoxSessionLiveActivityAttributes(),
            content: ActivityContent(
                state: .init(weeklyWordCount: weeklyWordCount),
                staleDate: nil
            ),
            pushType: nil
        )
        self.activity = activity
        lastWeeklyWordCount = weeklyWordCount
    }

    func end() async {
        guard let activity = currentActivity else { return }

        await activity.end(nil, dismissalPolicy: .immediate)
        self.activity = nil
        lastWeeklyWordCount = nil
    }

    private var currentActivity: Activity<KeyVoxSessionLiveActivityAttributes>? {
        if let activity {
            return activity
        }

        activity = Activity<KeyVoxSessionLiveActivityAttributes>.activities.first
        return activity
    }
}

@MainActor
final class KeyVoxSessionLiveActivityCoordinator {
    private let liveActivityController: any KeyVoxSessionLiveActivityControlling
    private var cancellables = Set<AnyCancellable>()

    private var isSessionActive: Bool
    private var sessionDisablePending: Bool
    private var liveActivitiesEnabled: Bool
    private var weeklyWordCount: Int
    private var isAudioRecordingStartPending = false

    init(
        initialIsSessionActive: Bool,
        initialSessionDisablePending: Bool,
        initialLiveActivitiesEnabled: Bool,
        initialWeeklyWordCount: Int,
        isSessionActivePublisher: AnyPublisher<Bool, Never>,
        sessionDisablePendingPublisher: AnyPublisher<Bool, Never>,
        liveActivitiesEnabledPublisher: AnyPublisher<Bool, Never>,
        weeklyWordCountPublisher: AnyPublisher<Int, Never>,
        liveActivityController: (any KeyVoxSessionLiveActivityControlling)? = nil
    ) {
        self.isSessionActive = initialIsSessionActive
        self.sessionDisablePending = initialSessionDisablePending
        self.liveActivitiesEnabled = initialLiveActivitiesEnabled
        self.weeklyWordCount = initialWeeklyWordCount
        self.liveActivityController = liveActivityController ?? KeyVoxSessionLiveActivityController()

        bind(
            isSessionActivePublisher: isSessionActivePublisher,
            sessionDisablePendingPublisher: sessionDisablePendingPublisher,
            liveActivitiesEnabledPublisher: liveActivitiesEnabledPublisher,
            weeklyWordCountPublisher: weeklyWordCountPublisher
        )

        Task { @MainActor [self] in
            await reconcileActivity()
        }
    }

    func applyState(
        isSessionActive: Bool,
        sessionDisablePending: Bool,
        liveActivitiesEnabled: Bool,
        weeklyWordCount: Int
    ) async {
        self.isSessionActive = isSessionActive
        self.sessionDisablePending = sessionDisablePending
        self.liveActivitiesEnabled = liveActivitiesEnabled
        self.weeklyWordCount = weeklyWordCount
        await reconcileActivity()
    }

    func prepareForAudioRecordingIntent() async throws {
        guard liveActivitiesEnabled else {
            throw KeyVoxRequiredLiveActivityError.disabled
        }

        isAudioRecordingStartPending = true
        do {
            try await liveActivityController.startOrUpdate(weeklyWordCount: weeklyWordCount)
        } catch {
            isAudioRecordingStartPending = false
            throw error
        }
    }

    func completeAudioRecordingIntentStart(
        isSessionActive: Bool,
        sessionDisablePending: Bool
    ) async {
        self.isSessionActive = isSessionActive
        self.sessionDisablePending = sessionDisablePending
        isAudioRecordingStartPending = false
        await reconcileActivity()
    }

    private func bind(
        isSessionActivePublisher: AnyPublisher<Bool, Never>,
        sessionDisablePendingPublisher: AnyPublisher<Bool, Never>,
        liveActivitiesEnabledPublisher: AnyPublisher<Bool, Never>,
        weeklyWordCountPublisher: AnyPublisher<Int, Never>
    ) {
        isSessionActivePublisher
            .removeDuplicates()
            .sink { [weak self] isSessionActive in
                guard let self else { return }
                Task { @MainActor [weak self] in
                    guard let self else { return }
                    await self.applyState(
                        isSessionActive: isSessionActive,
                        sessionDisablePending: self.sessionDisablePending,
                        liveActivitiesEnabled: self.liveActivitiesEnabled,
                        weeklyWordCount: self.weeklyWordCount
                    )
                }
            }
            .store(in: &cancellables)

        sessionDisablePendingPublisher
            .removeDuplicates()
            .sink { [weak self] sessionDisablePending in
                guard let self else { return }
                Task { @MainActor [weak self] in
                    guard let self else { return }
                    await self.applyState(
                        isSessionActive: self.isSessionActive,
                        sessionDisablePending: sessionDisablePending,
                        liveActivitiesEnabled: self.liveActivitiesEnabled,
                        weeklyWordCount: self.weeklyWordCount
                    )
                }
            }
            .store(in: &cancellables)

        liveActivitiesEnabledPublisher
            .removeDuplicates()
            .sink { [weak self] liveActivitiesEnabled in
                guard let self else { return }
                Task { @MainActor [weak self] in
                    guard let self else { return }
                    await self.applyState(
                        isSessionActive: self.isSessionActive,
                        sessionDisablePending: self.sessionDisablePending,
                        liveActivitiesEnabled: liveActivitiesEnabled,
                        weeklyWordCount: self.weeklyWordCount
                    )
                }
            }
            .store(in: &cancellables)

        weeklyWordCountPublisher
            .removeDuplicates()
            .sink { [weak self] weeklyWordCount in
                guard let self else { return }
                Task { @MainActor [weak self] in
                    guard let self else { return }
                    await self.applyState(
                        isSessionActive: self.isSessionActive,
                        sessionDisablePending: self.sessionDisablePending,
                        liveActivitiesEnabled: self.liveActivitiesEnabled,
                        weeklyWordCount: weeklyWordCount
                    )
                }
            }
            .store(in: &cancellables)
    }

    private func reconcileActivity() async {
        guard shouldShowActivity else {
            guard liveActivityController.isActivityActive else { return }
            await liveActivityController.end()
            return
        }

        do {
            try await liveActivityController.startOrUpdate(weeklyWordCount: weeklyWordCount)
        } catch {
            #if DEBUG
            print("[KeyVoxSessionLiveActivityCoordinator] Failed to reconcile activity: \(error)")
            #endif
        }
    }

    private var shouldShowActivity: Bool {
        isAudioRecordingStartPending
            || (liveActivitiesEnabled && isSessionActive && !sessionDisablePending)
    }
}

enum KeyVoxRequiredLiveActivityError: LocalizedError {
    case disabled

    var errorDescription: String? {
        switch self {
        case .disabled:
            String(localized: "Live Activities must be enabled in KeyVox before background dictation can start.")
        }
    }
}
