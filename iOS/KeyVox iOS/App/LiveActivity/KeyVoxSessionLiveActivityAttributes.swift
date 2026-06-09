import ActivityKit

struct KeyVoxSessionLiveActivityAttributes: nonisolated ActivityAttributes {
    struct ContentState: Codable, Hashable {
        let weeklyWordCount: Int
    }
}
