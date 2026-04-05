import Combine
import Foundation

@MainActor
final class WeeklyWordStatsCloudSync {
    private let ubiquitousStore: any CloudKeyValueStoring
    private let notificationCenter: NotificationCenter
    private let weeklyWordStatsStore: WeeklyWordStatsStore
    private let now: () -> Date

    private var cancellables = Set<AnyCancellable>()
    private var externalChangeObserver: NSObjectProtocol?
    private var isApplyingRemoteSnapshot = false

    init(
        ubiquitousStore: any CloudKeyValueStoring = NSUbiquitousKeyValueStore.default,
        notificationCenter: NotificationCenter = .default,
        weeklyWordStatsStore: WeeklyWordStatsStore,
        now: @escaping () -> Date = Date.init
    ) {
        self.ubiquitousStore = ubiquitousStore
        self.notificationCenter = notificationCenter
        self.weeklyWordStatsStore = weeklyWordStatsStore
        self.now = now

        setupObservers()
        registerForExternalChanges()
        _ = ubiquitousStore.synchronize()
        bootstrap()
    }

    deinit {
        if let externalChangeObserver {
            notificationCenter.removeObserver(externalChangeObserver)
        }
    }

    func processExternalChanges(for changedKeys: [String]) {
        if changedKeys.contains(KeyVoxiCloudKeys.weeklyWordStatsPayload)
            || changedKeys.contains(KeyVoxiCloudKeys.weeklyWordStatsModifiedAt) {
            resolve(remoteSnapshot: loadRemoteSnapshot())
        }
    }

    private func setupObservers() {
        weeklyWordStatsStore.$snapshot
            .dropFirst()
            .sink { [weak self] snapshot in
                guard let self, !self.isApplyingRemoteSnapshot else { return }
                self.resolve(localSnapshot: snapshot, remoteSnapshot: self.loadRemoteSnapshot())
            }
            .store(in: &cancellables)
    }

    private func registerForExternalChanges() {
        guard let notificationObject = ubiquitousStore.notificationObject else { return }
        externalChangeObserver = notificationCenter.addObserver(
            forName: NSUbiquitousKeyValueStore.didChangeExternallyNotification,
            object: notificationObject,
            queue: .main
        ) { [weak self] notification in
            guard
                let userInfo = notification.userInfo,
                let changedKeys = userInfo[NSUbiquitousKeyValueStoreChangedKeysKey] as? [String]
            else {
                return
            }

            Task { @MainActor [weak self] in
                self?.processExternalChanges(for: changedKeys)
            }
        }
    }

    private func bootstrap() {
        resolve(remoteSnapshot: loadRemoteSnapshot())
    }

    private func resolve(remoteSnapshot: WeeklyWordStatsPayload?) {
        resolve(localSnapshot: weeklyWordStatsStore.snapshot, remoteSnapshot: remoteSnapshot)
    }

    private func resolve(localSnapshot: WeeklyWordStatsPayload, remoteSnapshot: WeeklyWordStatsPayload?) {
        guard let remoteSnapshot else {
            if !localSnapshot.isEmpty {
                push(snapshot: localSnapshot)
            }
            return
        }

        if remoteSnapshot.weekStart > localSnapshot.weekStart {
            applyRemoteSnapshot(remoteSnapshot)
            return
        }

        if remoteSnapshot.weekStart < localSnapshot.weekStart {
            push(snapshot: localSnapshot)
            return
        }

        let mergedSnapshot = mergedSnapshot(local: localSnapshot, remote: remoteSnapshot)
        let snapshotsAlreadyConverged =
            mergedSnapshot.deviceWordCounts == localSnapshot.deviceWordCounts
            && mergedSnapshot.deviceWordCounts == remoteSnapshot.deviceWordCounts

        guard !snapshotsAlreadyConverged else { return }

        applyRemoteSnapshot(mergedSnapshot)

        guard mergedSnapshot != remoteSnapshot else { return }
        push(snapshot: mergedSnapshot)
    }

    private func mergedSnapshot(local: WeeklyWordStatsPayload, remote: WeeklyWordStatsPayload) -> WeeklyWordStatsPayload {
        var mergedCounts = local.deviceWordCounts

        for (deviceID, remoteCount) in remote.deviceWordCounts {
            mergedCounts[deviceID] = max(mergedCounts[deviceID] ?? 0, remoteCount)
        }

        return WeeklyWordStatsPayload(
            weekStart: local.weekStart,
            modifiedAt: now(),
            deviceWordCounts: mergedCounts
        ).sanitized()
    }

    private func applyRemoteSnapshot(_ snapshot: WeeklyWordStatsPayload) {
        isApplyingRemoteSnapshot = true
        defer { isApplyingRemoteSnapshot = false }
        weeklyWordStatsStore.applySynchronizedSnapshot(snapshot)
    }

    private func push(snapshot: WeeklyWordStatsPayload) {
        do {
            let data = try JSONEncoder().encode(snapshot)
            ubiquitousStore.set(data, forKey: KeyVoxiCloudKeys.weeklyWordStatsPayload)
            ubiquitousStore.set(snapshot.modifiedAt, forKey: KeyVoxiCloudKeys.weeklyWordStatsModifiedAt)
            _ = ubiquitousStore.synchronize()
        } catch {
            #if DEBUG
            print("[WeeklyWordStatsCloudSync] Failed to encode weekly word stats payload: \(error)")
            #endif
        }
    }

    private func loadRemoteSnapshot() -> WeeklyWordStatsPayload? {
        guard let data = ubiquitousStore.data(forKey: KeyVoxiCloudKeys.weeklyWordStatsPayload) else {
            return nil
        }

        do {
            return try JSONDecoder().decode(WeeklyWordStatsPayload.self, from: data).sanitized()
        } catch {
            #if DEBUG
            print("[WeeklyWordStatsCloudSync] Failed to decode weekly word stats payload: \(error)")
            #endif
            return nil
        }
    }
}
