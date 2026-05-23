import Foundation

enum KeyVoxVibesTrialRemainingTimeFormatter {
    static func fullDayCountText(for duration: TimeInterval) -> String {
        "\(Int(ceil(max(0, duration) / 86_400)))"
    }

    static func remainingText(for remainingTime: TimeInterval) -> String {
        let remainingSeconds = Int(ceil(max(0, remainingTime)))
        let days = remainingSeconds / 86_400
        let hours = (remainingSeconds % 86_400) / 3_600
        let minutes = (remainingSeconds % 3_600) / 60
        var components: [String] = []

        if days > 0 {
            components.append("\(days)d")
        }

        if hours > 0 {
            components.append("\(hours)h")
        }

        if days == 0, minutes > 0 {
            components.append("\(minutes)m")
        }

        guard components.isEmpty else {
            return components.joined(separator: " ")
        }

        return remainingTime > 0 ? "1m" : "0m"
    }
}
