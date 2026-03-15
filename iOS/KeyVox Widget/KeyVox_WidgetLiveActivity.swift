import ActivityKit
import WidgetKit
import SwiftUI
import AppIntents
import UIKit

struct KeyVox_WidgetLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: KeyVoxSessionLiveActivityAttributes.self) { context in
            KeyVoxSessionLockScreenView(context: context)
                .activityBackgroundTint(Color(uiColor: .systemBackground).opacity(0.5))
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    KeyVoxDynamicIslandBrandView()
                }
                DynamicIslandExpandedRegion(.trailing) {
                    KeyVoxSessionStopButton()
                }
                DynamicIslandExpandedRegion(.bottom) {
                    Text(wordsThisWeekLabel(for: context.state.weeklyWordCount))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            } compactLeading: {
                KeyVoxDynamicIslandLogo()
            } compactTrailing: {
                EmptyView()
            } minimal: {
                KeyVoxDynamicIslandLogo()
            }
        }
    }
}

private struct KeyVoxSessionLockScreenView: View {
    let context: ActivityViewContext<KeyVoxSessionLiveActivityAttributes>

    var body: some View {
        HStack(spacing: 14) {
            VStack(alignment: .leading, spacing: 6) {
                KeyVoxDynamicIslandBrandView()
                Text(wordsThisWeekLabel(for: context.state.weeklyWordCount))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer(minLength: 12)

            KeyVoxSessionStopButton()
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 14)
    }
}

private struct KeyVoxDynamicIslandBrandView: View {
    var body: some View {
        HStack(spacing: 3) {
            KeyVoxDynamicIslandLogo()

            Text("KeyVox")
                .font(.custom("Kanit-Medium", size: 22))
                .foregroundStyle(.primary)
        }
    }
}

private struct KeyVoxDynamicIslandLogo: View {
    var body: some View {
        Image("logo-white-island", bundle: .main)
            .resizable()
            .renderingMode(.template)
            .scaledToFit()
            .frame(width: 27, height: 27)
            .foregroundStyle(.primary)
    }
}

private struct KeyVoxSessionStopButton: View {
    var body: some View {
        Button(intent: EndSessionIntent()) {
            Image("logo-white-ios", bundle: .main)
                .resizable()
                .renderingMode(.template)
                .scaledToFit()
                .frame(width: 29, height: 29)
                .foregroundStyle(.primary)
                .padding(10)
                .background(
                    Circle()
                        .fill(Color(uiColor: .white).opacity(0.2))
                )
        }
        .buttonStyle(.plain)
        .accessibilityLabel("End dictation session")
    }
}

private func wordsThisWeekLabel(for weeklyWordCount: Int) -> String {
    let wordLabel = weeklyWordCount == 1 ? "word" : "words"
    return "\(weeklyWordCount.formatted()) \(wordLabel) this week!"
}

#Preview("Notification", as: .content, using: KeyVoxSessionLiveActivityAttributes()) {
    KeyVox_WidgetLiveActivity()
} contentStates: {
    KeyVoxSessionLiveActivityAttributes.ContentState(weeklyWordCount: 1284)
}
