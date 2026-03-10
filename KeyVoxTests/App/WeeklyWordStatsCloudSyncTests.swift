import Foundation
import XCTest
@testable import KeyVox

@MainActor
final class WeeklyWordStatsCloudSyncTests: XCTestCase {
    func testLocalSnapshotSeedsEmptyCloud() throws {
        let harness = makeHarness(now: makeDate(year: 2026, month: 3, day: 10, hour: 12))
        harness.store.recordSpokenWords(from: "one two three", at: harness.now())

        let sync = WeeklyWordStatsCloudSync(
            ubiquitousStore: harness.cloudStore,
            notificationCenter: harness.notificationCenter,
            weeklyWordStatsStore: harness.store,
            now: harness.now
        )
        _ = sync

        XCTAssertEqual(try harness.cloudStore.weeklyPayload(), harness.store.snapshot)
        XCTAssertEqual(harness.cloudStore.setCount(forKey: KeyVoxiCloudKeys.weeklyWordStatsPayload), 1)
    }

    func testRemoteSnapshotSeedsEmptyLocalStore() throws {
        let harness = makeHarness(now: makeDate(year: 2026, month: 3, day: 10, hour: 12))
        let remoteSnapshot = makeSnapshot(
            weekStart: harness.weekStart,
            modifiedAt: harness.now(),
            deviceWordCounts: ["device-remote": 11]
        )
        try harness.cloudStore.seedWeeklyPayload(remoteSnapshot)

        let sync = WeeklyWordStatsCloudSync(
            ubiquitousStore: harness.cloudStore,
            notificationCenter: harness.notificationCenter,
            weeklyWordStatsStore: harness.store,
            now: harness.now
        )
        _ = sync

        XCTAssertEqual(harness.store.snapshot, remoteSnapshot)
        XCTAssertEqual(harness.store.combinedWordCount, 11)
    }

    func testSameWeekMergeCombinesDeviceTotalsAndPushesMergedSnapshot() throws {
        let harness = makeHarness(now: makeDate(year: 2026, month: 3, day: 10, hour: 12))
        harness.store.applySynchronizedSnapshot(
            makeSnapshot(
                weekStart: harness.weekStart,
                modifiedAt: harness.now(),
                deviceWordCounts: ["device-local": 9]
            )
        )
        try harness.cloudStore.seedWeeklyPayload(
            makeSnapshot(
                weekStart: harness.weekStart,
                modifiedAt: makeDate(year: 2026, month: 3, day: 10, hour: 11),
                deviceWordCounts: ["device-remote": 6]
            )
        )

        let sync = WeeklyWordStatsCloudSync(
            ubiquitousStore: harness.cloudStore,
            notificationCenter: harness.notificationCenter,
            weeklyWordStatsStore: harness.store,
            now: harness.now
        )
        _ = sync

        XCTAssertEqual(harness.store.snapshot.deviceWordCounts, ["device-local": 9, "device-remote": 6])
        XCTAssertEqual(harness.store.combinedWordCount, 15)
        XCTAssertEqual(try harness.cloudStore.weeklyPayload(), harness.store.snapshot)
    }

    func testSameWeekMergeKeepsLargestCountForSameDevice() throws {
        let harness = makeHarness(now: makeDate(year: 2026, month: 3, day: 10, hour: 12))
        harness.store.applySynchronizedSnapshot(
            makeSnapshot(
                weekStart: harness.weekStart,
                modifiedAt: harness.now(),
                deviceWordCounts: ["device-shared": 12]
            )
        )
        try harness.cloudStore.seedWeeklyPayload(
            makeSnapshot(
                weekStart: harness.weekStart,
                modifiedAt: makeDate(year: 2026, month: 3, day: 10, hour: 11),
                deviceWordCounts: ["device-shared": 7, "device-other": 4]
            )
        )

        let sync = WeeklyWordStatsCloudSync(
            ubiquitousStore: harness.cloudStore,
            notificationCenter: harness.notificationCenter,
            weeklyWordStatsStore: harness.store,
            now: harness.now
        )
        _ = sync

        XCTAssertEqual(harness.store.snapshot.deviceWordCounts["device-shared"], 12)
        XCTAssertEqual(harness.store.snapshot.deviceWordCounts["device-other"], 4)
        XCTAssertEqual(harness.store.combinedWordCount, 16)
    }

    func testNewerRemoteWeekReplacesOlderLocalWeek() throws {
        let localNow = makeDate(year: 2026, month: 3, day: 10, hour: 12)
        let remoteNow = makeDate(year: 2026, month: 3, day: 17, hour: 12)
        let harness = makeHarness(now: remoteNow)
        harness.store.applySynchronizedSnapshot(
            makeSnapshot(
                weekStart: harness.calendar.dateInterval(of: .weekOfYear, for: localNow)!.start,
                modifiedAt: localNow,
                deviceWordCounts: ["device-local": 5]
            )
        )
        try harness.cloudStore.seedWeeklyPayload(
            makeSnapshot(
                weekStart: harness.calendar.dateInterval(of: .weekOfYear, for: remoteNow)!.start,
                modifiedAt: remoteNow,
                deviceWordCounts: ["device-remote": 8]
            )
        )

        let sync = WeeklyWordStatsCloudSync(
            ubiquitousStore: harness.cloudStore,
            notificationCenter: harness.notificationCenter,
            weeklyWordStatsStore: harness.store,
            now: harness.now
        )
        _ = sync

        XCTAssertEqual(harness.store.snapshot.deviceWordCounts, ["device-remote": 8])
        XCTAssertEqual(harness.store.snapshot.weekStart, harness.calendar.dateInterval(of: .weekOfYear, for: remoteNow)!.start)
    }

    func testOlderRemoteWeekIsIgnoredAndLocalSnapshotWins() throws {
        let localNow = makeDate(year: 2026, month: 3, day: 17, hour: 12)
        let remoteNow = makeDate(year: 2026, month: 3, day: 10, hour: 12)
        let harness = makeHarness(now: localNow)
        harness.store.applySynchronizedSnapshot(
            makeSnapshot(
                weekStart: harness.calendar.dateInterval(of: .weekOfYear, for: localNow)!.start,
                modifiedAt: localNow,
                deviceWordCounts: ["device-local": 13]
            )
        )
        try harness.cloudStore.seedWeeklyPayload(
            makeSnapshot(
                weekStart: harness.calendar.dateInterval(of: .weekOfYear, for: remoteNow)!.start,
                modifiedAt: remoteNow,
                deviceWordCounts: ["device-remote": 4]
            )
        )

        let sync = WeeklyWordStatsCloudSync(
            ubiquitousStore: harness.cloudStore,
            notificationCenter: harness.notificationCenter,
            weeklyWordStatsStore: harness.store,
            now: harness.now
        )
        _ = sync

        XCTAssertEqual(harness.store.snapshot.deviceWordCounts, ["device-local": 13])
        XCTAssertEqual(try harness.cloudStore.weeklyPayload(), harness.store.snapshot)
    }

    private func makeHarness(now: Date, initialNow: Date? = nil) -> WeeklyHarness {
        let suiteName = "WeeklyWordStatsCloudSyncTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)

        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let storeNow = initialNow ?? now
        let store = WeeklyWordStatsStore(
            defaults: defaults,
            calendar: calendar,
            now: { storeNow },
            installationIDGenerator: { "device-local" }
        )

        addTeardownBlock {
            defaults.removePersistentDomain(forName: suiteName)
        }

        return WeeklyHarness(
            defaults: defaults,
            store: store,
            cloudStore: InMemoryWeeklyWordStatsCloudStore(),
            notificationCenter: NotificationCenter(),
            calendar: calendar,
            now: { now },
            weekStart: calendar.dateInterval(of: .weekOfYear, for: now)!.start
        )
    }

    private func makeSnapshot(weekStart: Date, modifiedAt: Date, deviceWordCounts: [String: Int]) -> WeeklyWordStatsPayload {
        WeeklyWordStatsPayload(
            weekStart: weekStart,
            modifiedAt: modifiedAt,
            deviceWordCounts: deviceWordCounts
        )
    }

    private func makeDate(year: Int, month: Int, day: Int, hour: Int) -> Date {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        return DateComponents(
            calendar: calendar,
            timeZone: calendar.timeZone,
            year: year,
            month: month,
            day: day,
            hour: hour
        ).date!
    }
}

private struct WeeklyHarness {
    let defaults: UserDefaults
    let store: WeeklyWordStatsStore
    let cloudStore: InMemoryWeeklyWordStatsCloudStore
    let notificationCenter: NotificationCenter
    let calendar: Calendar
    let now: () -> Date
    let weekStart: Date
}

private final class InMemoryWeeklyWordStatsCloudStore: KeyVoxiCloudKeyValueStoring {
    var notificationObject: AnyObject? { nil }

    private var storage: [String: Any] = [:]
    private var setCounts: [String: Int] = [:]

    func object(forKey key: String) -> Any? {
        storage[key]
    }

    func data(forKey key: String) -> Data? {
        storage[key] as? Data
    }

    func bool(forKey key: String) -> Bool {
        storage[key] as? Bool ?? false
    }

    func set(_ value: Any?, forKey key: String) {
        storage[key] = value
        setCounts[key, default: 0] += 1
    }

    func synchronize() -> Bool {
        true
    }

    func seedWeeklyPayload(_ payload: WeeklyWordStatsPayload) throws {
        storage[KeyVoxiCloudKeys.weeklyWordStatsPayload] = try JSONEncoder().encode(payload)
        storage[KeyVoxiCloudKeys.weeklyWordStatsModifiedAt] = payload.modifiedAt
    }

    func weeklyPayload() throws -> WeeklyWordStatsPayload? {
        guard let data = storage[KeyVoxiCloudKeys.weeklyWordStatsPayload] as? Data else { return nil }
        return try JSONDecoder().decode(WeeklyWordStatsPayload.self, from: data)
    }

    func setCount(forKey key: String) -> Int {
        setCounts[key, default: 0]
    }
}
