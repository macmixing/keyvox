import Foundation

enum KeyVoxVibesTrialRemainingTimeFormatter {
    static func fullDayCount(for duration: TimeInterval) -> Int {
        Int(ceil(max(0, duration) / 86_400))
    }

    static func remainingText(for remainingTime: TimeInterval) -> String {
        let remainingSeconds = Int(ceil(max(0, remainingTime)))
        let days = remainingSeconds / 86_400
        let hours = (remainingSeconds % 86_400) / 3_600
        let minutes = (remainingSeconds % 3_600) / 60

        let shownMinutes = days == 0 ? minutes : 0
        if days > 0 || hours > 0 || shownMinutes > 0 {
            let shownComponents = DateComponents(day: days, hour: hours, minute: shownMinutes)
            return abbreviatedFormatter(dropsZeroUnits: true).string(from: shownComponents) ?? ""
        }

        let fallbackComponents = DateComponents(minute: remainingTime > 0 ? 1 : 0)
        return abbreviatedFormatter(dropsZeroUnits: false).string(from: fallbackComponents) ?? ""
    }

    private static func abbreviatedFormatter(dropsZeroUnits: Bool) -> DateComponentsFormatter {
        let formatter = DateComponentsFormatter()
        formatter.unitsStyle = .abbreviated
        formatter.allowedUnits = [.day, .hour, .minute]
        formatter.zeroFormattingBehavior = dropsZeroUnits ? .dropAll : .default
        return formatter
    }
}
