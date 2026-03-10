import Foundation
import XCTest
@testable import KeyVox

@MainActor
final class WeeklyWordStatsStoreTests: XCTestCase {
    func testInitCreatesStableInstallationIDAndEmptyCurrentWeekSnapshot() throws {
        let (defaults, suiteName) = makeIsolatedDefaults()
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let calendar = makeCalendar()
        let now = makeDate(calendar: calendar, year: 2026, month: 3, day: 10)

        let store = WeeklyWordStatsStore(
            defaults: defaults,
            calendar: calendar,
            now: { now },
            installationIDGenerator: { "device-a" }
        )

        XCTAssertEqual(store.installationID, "device-a")
        XCTAssertEqual(defaults.string(forKey: UserDefaultsKeys.App.weeklyWordStatsInstallationID), "device-a")
        XCTAssertEqual(store.snapshot.weekStart, calendar.dateInterval(of: .weekOfYear, for: now)?.start)
        XCTAssertEqual(store.snapshot.deviceWordCounts, [:])
        XCTAssertEqual(store.combinedWordCount, 0)

        let persisted = try XCTUnwrap(defaults.data(forKey: UserDefaultsKeys.App.weeklyWordStatsPayload))
        let decoded = try JSONDecoder().decode(WeeklyWordStatsPayload.self, from: persisted)
        XCTAssertEqual(decoded, store.snapshot)
    }

    func testInitHydratesPersistedSnapshotForCurrentWeek() {
        let (defaults, suiteName) = makeIsolatedDefaults()
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let calendar = makeCalendar()
        let now = makeDate(calendar: calendar, year: 2026, month: 3, day: 10)
        let weekStart = calendar.dateInterval(of: .weekOfYear, for: now)!.start
        let stored = WeeklyWordStatsPayload(
            weekStart: weekStart,
            modifiedAt: now,
            deviceWordCounts: ["device-a": 14, "device-b": 9]
        )

        defaults.set("persisted-device", forKey: UserDefaultsKeys.App.weeklyWordStatsInstallationID)
        defaults.set(try! JSONEncoder().encode(stored), forKey: UserDefaultsKeys.App.weeklyWordStatsPayload)

        let store = WeeklyWordStatsStore(
            defaults: defaults,
            calendar: calendar,
            now: { now },
            installationIDGenerator: { "unused" }
        )

        XCTAssertEqual(store.installationID, "persisted-device")
        XCTAssertEqual(store.snapshot, stored)
        XCTAssertEqual(store.combinedWordCount, 23)
    }

    func testRecordSpokenWordsIncrementsOnlyLocalContributionAndIgnoresWhitespace() {
        let (defaults, suiteName) = makeIsolatedDefaults()
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let calendar = makeCalendar()
        let now = makeDate(calendar: calendar, year: 2026, month: 3, day: 10)
        let store = WeeklyWordStatsStore(
            defaults: defaults,
            calendar: calendar,
            now: { now },
            installationIDGenerator: { "device-a" }
        )

        store.applySynchronizedSnapshot(
            WeeklyWordStatsPayload(
                weekStart: calendar.dateInterval(of: .weekOfYear, for: now)!.start,
                modifiedAt: now,
                deviceWordCounts: ["device-b": 5]
            )
        )

        store.recordSpokenWords(from: "hello   weekly sync", at: now)
        XCTAssertEqual(store.snapshot.deviceWordCounts["device-a"], 3)
        XCTAssertEqual(store.snapshot.deviceWordCounts["device-b"], 5)
        XCTAssertEqual(store.combinedWordCount, 8)

        store.recordSpokenWords(from: "   \n\t  ", at: now)
        XCTAssertEqual(store.snapshot.deviceWordCounts["device-a"], 3)
        XCTAssertEqual(store.combinedWordCount, 8)
    }

    func testRefreshWeeklyWordStatsIfNeededRollsIntoNewWeek() {
        let (defaults, suiteName) = makeIsolatedDefaults()
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let calendar = makeCalendar()
        let weekOneDate = makeDate(calendar: calendar, year: 2026, month: 3, day: 10)
        let nextWeekDate = makeDate(calendar: calendar, year: 2026, month: 3, day: 17)
        let store = WeeklyWordStatsStore(
            defaults: defaults,
            calendar: calendar,
            now: { weekOneDate },
            installationIDGenerator: { "device-a" }
        )

        store.recordSpokenWords(from: "one two", at: weekOneDate)
        XCTAssertEqual(store.combinedWordCount, 2)

        store.refreshWeeklyWordStatsIfNeeded(referenceDate: nextWeekDate)

        XCTAssertEqual(store.snapshot.weekStart, calendar.dateInterval(of: .weekOfYear, for: nextWeekDate)?.start)
        XCTAssertEqual(store.snapshot.deviceWordCounts, [:])
        XCTAssertEqual(store.combinedWordCount, 0)
    }

    private func makeIsolatedDefaults() -> (UserDefaults, String) {
        let suiteName = "WeeklyWordStatsStoreTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        return (defaults, suiteName)
    }

    private func makeCalendar() -> Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        return calendar
    }

    private func makeDate(
        calendar: Calendar,
        year: Int,
        month: Int,
        day: Int
    ) -> Date {
        DateComponents(
            calendar: calendar,
            timeZone: calendar.timeZone,
            year: year,
            month: month,
            day: day,
            hour: 12
        ).date!
    }
}
