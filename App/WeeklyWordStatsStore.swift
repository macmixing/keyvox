import Foundation
import Combine

@MainActor
final class WeeklyWordStatsStore: ObservableObject {
    static let shared = WeeklyWordStatsStore()

    @Published private(set) var snapshot: WeeklyWordStatsPayload

    var combinedWordCount: Int {
        snapshot.combinedWordCount
    }

    internal var installationID: String {
        localInstallationID
    }

    private let defaults: UserDefaults
    private let calendar: Calendar
    private let now: () -> Date
    private let installationIDGenerator: () -> String
    private let localInstallationID: String

    deinit {}

    init(
        defaults: UserDefaults = .standard,
        calendar: Calendar = makeCanonicalWeekCalendar(),
        now: @escaping () -> Date = Date.init,
        installationIDGenerator: @escaping () -> String = { UUID().uuidString }
    ) {
        self.defaults = defaults
        self.calendar = calendar
        self.now = now
        self.installationIDGenerator = installationIDGenerator

        let nowDate = now()
        let currentWeekStart = Self.weekStart(for: nowDate, calendar: calendar)

        if let existingInstallationID = defaults.string(forKey: UserDefaultsKeys.App.weeklyWordStatsInstallationID),
           !existingInstallationID.isEmpty {
            localInstallationID = existingInstallationID
        } else {
            let generatedInstallationID = installationIDGenerator()
            localInstallationID = generatedInstallationID
            defaults.set(generatedInstallationID, forKey: UserDefaultsKeys.App.weeklyWordStatsInstallationID)
        }

        if
            let data = defaults.data(forKey: UserDefaultsKeys.App.weeklyWordStatsPayload),
            let storedSnapshot = try? JSONDecoder().decode(WeeklyWordStatsPayload.self, from: data),
            calendar.isDate(storedSnapshot.weekStart, inSameDayAs: currentWeekStart)
        {
            snapshot = storedSnapshot.sanitized()
        } else {
            snapshot = WeeklyWordStatsPayload.empty(weekStart: currentWeekStart, modifiedAt: nowDate)
            persistSnapshot()
        }
    }

    func recordSpokenWords(from text: String, at date: Date? = nil) {
        let referenceDate = date ?? now()
        refreshWeeklyWordStatsIfNeeded(referenceDate: referenceDate)

        let count = text.split(whereSeparator: \.isWhitespace).count
        guard count > 0 else { return }

        var deviceWordCounts = snapshot.deviceWordCounts
        deviceWordCounts[localInstallationID, default: 0] += count

        setSnapshot(
            WeeklyWordStatsPayload(
                weekStart: Self.weekStart(for: referenceDate, calendar: calendar),
                modifiedAt: referenceDate,
                deviceWordCounts: deviceWordCounts
            )
        )
    }

    func refreshWeeklyWordStatsIfNeeded(referenceDate: Date? = nil) {
        let evaluatedDate = referenceDate ?? now()
        let currentWeekStart = Self.weekStart(for: evaluatedDate, calendar: calendar)
        guard !calendar.isDate(snapshot.weekStart, inSameDayAs: currentWeekStart) else { return }

        setSnapshot(
            WeeklyWordStatsPayload.empty(
                weekStart: currentWeekStart,
                modifiedAt: evaluatedDate
            )
        )
    }

    internal func applySynchronizedSnapshot(_ snapshot: WeeklyWordStatsPayload) {
        setSnapshot(snapshot)
    }

    private func setSnapshot(_ newSnapshot: WeeklyWordStatsPayload) {
        let sanitizedSnapshot = newSnapshot.sanitized()
        guard snapshot != sanitizedSnapshot else { return }
        snapshot = sanitizedSnapshot
        persistSnapshot()
    }

    private func persistSnapshot() {
        if let data = try? JSONEncoder().encode(snapshot) {
            defaults.set(data, forKey: UserDefaultsKeys.App.weeklyWordStatsPayload)
        }
    }

    private static func weekStart(for date: Date, calendar: Calendar) -> Date {
        calendar.dateInterval(of: .weekOfYear, for: date)?.start ?? date
    }
}

nonisolated private func makeCanonicalWeekCalendar() -> Calendar {
    var calendar = Calendar(identifier: .iso8601)
    calendar.locale = Locale(identifier: "en_US_POSIX")
    calendar.timeZone = TimeZone(secondsFromGMT: 0) ?? .gmt
    return calendar
}
