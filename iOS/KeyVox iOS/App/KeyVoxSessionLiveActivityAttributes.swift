import ActivityKit

struct KeyVoxSessionLiveActivityAttributes: ActivityAttributes {
    struct ContentState: Codable, Hashable {
        let weeklyWordCount: Int
    }
}
