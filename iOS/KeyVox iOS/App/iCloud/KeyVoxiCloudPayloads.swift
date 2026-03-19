import Foundation
import KeyVoxCore

nonisolated struct KeyVoxDictionaryCloudPayload: Codable, Equatable {
    let modifiedAt: Date
    let entries: [DictionaryEntry]
}

nonisolated struct WeeklyWordStatsPayload: Codable, Equatable {
    let weekStart: Date
    let modifiedAt: Date
    let deviceWordCounts: [String: Int]

    var combinedWordCount: Int {
        deviceWordCounts.values.reduce(0, +)
    }

    var isEmpty: Bool {
        deviceWordCounts.isEmpty
    }

    func sanitized() -> WeeklyWordStatsPayload {
        WeeklyWordStatsPayload(
            weekStart: weekStart,
            modifiedAt: modifiedAt,
            deviceWordCounts: deviceWordCounts.reduce(into: [:]) { partialResult, element in
                guard element.value > 0 else { return }
                partialResult[element.key] = element.value
            }
        )
    }

    static func empty(weekStart: Date, modifiedAt: Date) -> WeeklyWordStatsPayload {
        WeeklyWordStatsPayload(
            weekStart: weekStart,
            modifiedAt: modifiedAt,
            deviceWordCounts: [:]
        )
    }
}
