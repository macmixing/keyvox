import ActivityKit
import Combine
import Foundation

@MainActor
protocol KeyVoxSessionLiveActivityControlling {
    var isActivityActive: Bool { get }
    func startOrUpdate(weeklyWordCount: Int) async
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

    func startOrUpdate(weeklyWordCount: Int) async {
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

        do {
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
        } catch {
            #if DEBUG
            print("[KeyVoxSessionLiveActivityController] Failed to request activity: \(error)")
            #endif
        }
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

        await liveActivityController.startOrUpdate(weeklyWordCount: weeklyWordCount)
    }

    private var shouldShowActivity: Bool {
        liveActivitiesEnabled && isSessionActive && !sessionDisablePending
    }
}
