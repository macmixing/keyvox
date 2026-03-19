import Foundation
import Testing
@testable import KeyVox_iOS

@MainActor
struct WeeklyWordStatsStoreTests {
    @Test func initPrefixesDefaultGeneratedInstallationIDForIOS() throws {
        let harness = makeHarness(now: makeDate(year: 2026, month: 3, day: 10))
        defer { harness.cleanup() }

        let store = WeeklyWordStatsStore(
            defaults: harness.defaults,
            calendar: harness.calendar,
            now: harness.now
        )

        #expect(store.installationID.hasPrefix("ios:"))
        #expect(harness.defaults.string(forKey: UserDefaultsKeys.App.weeklyWordStatsInstallationID)?.hasPrefix("ios:") == true)
    }

    @Test func initCreatesStableInstallationIDAndEmptyCurrentWeekSnapshot() throws {
        let harness = makeHarness(now: makeDate(year: 2026, month: 3, day: 10))
        defer { harness.cleanup() }

        let store = WeeklyWordStatsStore(
            defaults: harness.defaults,
            calendar: harness.calendar,
            now: harness.now,
            installationIDGenerator: { "device-a" }
        )

        #expect(store.installationID == "device-a")
        #expect(harness.defaults.string(forKey: UserDefaultsKeys.App.weeklyWordStatsInstallationID) == "device-a")
        #expect(store.snapshot.weekStart == harness.calendar.dateInterval(of: .weekOfYear, for: harness.now())?.start)
        #expect(store.snapshot.deviceWordCounts == [:])
        #expect(store.combinedWordCount == 0)

        let persisted = try #require(harness.defaults.data(forKey: UserDefaultsKeys.App.weeklyWordStatsPayload))
        let decoded = try JSONDecoder().decode(WeeklyWordStatsPayload.self, from: persisted)
        #expect(decoded == store.snapshot)
    }

    @Test func initHydratesPersistedSnapshotForCurrentWeek() throws {
        let harness = makeHarness(now: makeDate(year: 2026, month: 3, day: 10))
        defer { harness.cleanup() }
        let weekStart = harness.calendar.dateInterval(of: .weekOfYear, for: harness.now())!.start
        let stored = WeeklyWordStatsPayload(
            weekStart: weekStart,
            modifiedAt: harness.now(),
            deviceWordCounts: ["device-a": 14, "device-b": 9]
        )

        harness.defaults.set("persisted-device", forKey: UserDefaultsKeys.App.weeklyWordStatsInstallationID)
        harness.defaults.set(try JSONEncoder().encode(stored), forKey: UserDefaultsKeys.App.weeklyWordStatsPayload)

        let store = WeeklyWordStatsStore(
            defaults: harness.defaults,
            calendar: harness.calendar,
            now: harness.now,
            installationIDGenerator: { "unused" }
        )

        #expect(store.installationID == "persisted-device")
        #expect(store.snapshot == stored)
        #expect(store.combinedWordCount == 23)
    }

    @Test func recordSpokenWordsIncrementsOnlyLocalContributionAndIgnoresWhitespace() throws {
        let harness = makeHarness(now: makeDate(year: 2026, month: 3, day: 10))
        defer { harness.cleanup() }
        let store = WeeklyWordStatsStore(
            defaults: harness.defaults,
            calendar: harness.calendar,
            now: harness.now,
            installationIDGenerator: { "device-a" }
        )

        store.applySynchronizedSnapshot(
            WeeklyWordStatsPayload(
                weekStart: harness.calendar.dateInterval(of: .weekOfYear, for: harness.now())!.start,
                modifiedAt: harness.now(),
                deviceWordCounts: ["device-b": 5]
            )
        )

        store.recordSpokenWords(from: "hello   weekly sync", at: harness.now())
        #expect(store.snapshot.deviceWordCounts["device-a"] == 3)
        #expect(store.snapshot.deviceWordCounts["device-b"] == 5)
        #expect(store.combinedWordCount == 8)

        store.recordSpokenWords(from: "   \n\t  ", at: harness.now())
        #expect(store.snapshot.deviceWordCounts["device-a"] == 3)
        #expect(store.combinedWordCount == 8)
    }

    @Test func refreshWeeklyWordStatsIfNeededRollsIntoNewWeek() throws {
        let weekOneDate = makeDate(year: 2026, month: 3, day: 10)
        let nextWeekDate = makeDate(year: 2026, month: 3, day: 17)
        let harness = makeHarness(now: weekOneDate)
        defer { harness.cleanup() }
        let store = WeeklyWordStatsStore(
            defaults: harness.defaults,
            calendar: harness.calendar,
            now: harness.now,
            installationIDGenerator: { "device-a" }
        )

        store.recordSpokenWords(from: "one two", at: weekOneDate)
        #expect(store.combinedWordCount == 2)

        store.refreshWeeklyWordStatsIfNeeded(referenceDate: nextWeekDate)

        #expect(store.snapshot.weekStart == harness.calendar.dateInterval(of: .weekOfYear, for: nextWeekDate)?.start)
        #expect(store.snapshot.deviceWordCounts == [:])
        #expect(store.combinedWordCount == 0)
    }

    @Test func applySynchronizedSnapshotIgnoresStaleWeekPayloads() throws {
        let currentDate = makeDate(year: 2026, month: 3, day: 17)
        let staleDate = makeDate(year: 2026, month: 3, day: 10)
        let harness = makeHarness(now: currentDate)
        defer { harness.cleanup() }
        let store = WeeklyWordStatsStore(
            defaults: harness.defaults,
            calendar: harness.calendar,
            now: harness.now,
            installationIDGenerator: { "device-a" }
        )

        store.recordSpokenWords(from: "one two", at: currentDate)
        let currentSnapshot = store.snapshot

        store.applySynchronizedSnapshot(
            WeeklyWordStatsPayload(
                weekStart: harness.calendar.dateInterval(of: .weekOfYear, for: staleDate)!.start,
                modifiedAt: staleDate,
                deviceWordCounts: ["device-b": 20]
            )
        )

        #expect(store.snapshot == currentSnapshot)
        #expect(store.combinedWordCount == 2)
    }

    private func makeHarness(now: Date) -> WeeklyStatsHarness {
        let suiteName = "WeeklyWordStatsStoreTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)

        var calendar = Calendar(identifier: .iso8601)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!

        return WeeklyStatsHarness(
            defaults: defaults,
            defaultsSuiteName: suiteName,
            calendar: calendar,
            now: { now }
        )
    }

    private func makeDate(year: Int, month: Int, day: Int) -> Date {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        return DateComponents(
            calendar: calendar,
            timeZone: calendar.timeZone,
            year: year,
            month: month,
            day: day,
            hour: 12
        ).date!
    }
}

private struct WeeklyStatsHarness {
    let defaults: UserDefaults
    let defaultsSuiteName: String
    let calendar: Calendar
    let now: () -> Date

    func cleanup() {
        defaults.removePersistentDomain(forName: defaultsSuiteName)
    }
}
