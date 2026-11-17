import ActivityKit
import Foundation
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
                    KeyVoxExpandedDynamicIslandTitleView()
                }
                DynamicIslandExpandedRegion(.leading, priority: 1) {
                    Text(wordsThisWeekLabel(for: context.state.weeklyWordCount))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.85)
                        .offset(y: -6)
                        .dynamicIsland(verticalPlacement: .belowIfTooWide)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    KeyVoxSessionStopButton()
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .trailing)
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

private struct KeyVoxExpandedDynamicIslandTitleView: View {
    var body: some View {
        Text(verbatim: "KeyVox")
            .font(.custom("Kanit-Medium", size: 23))
            .foregroundStyle(.primary)
            .lineLimit(1)
            .allowsTightening(true)
            .dynamicTypeSize(...DynamicTypeSize.xLarge)
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
        HStack(spacing: 6) {
            KeyVoxDynamicIslandLogo()

            Text(verbatim: "KeyVox")
                .font(.custom("Kanit-Medium", size: 22))
                .foregroundStyle(.primary)
        }
    }
}

private struct KeyVoxDynamicIslandLogo: View {
    var body: some View {
        Image("live-activity-island", bundle: .main)
            .resizable()
            .renderingMode(.template)
            .scaledToFit()
            .frame(width: 25, height: 25)
            .foregroundStyle(.primary)
    }
}

private struct KeyVoxSessionStopButton: View {
    var body: some View {
        Button(intent: EndSessionIntent()) {
            Image(systemName: "power")
                .resizable()
                .renderingMode(.template)
                .scaledToFit()
                .frame(width: 25, height: 25)
                .foregroundStyle(.primary)
                .padding(10)
        }
        .buttonStyle(KeyVoxLiveActivityButtonStyle())
        .accessibilityLabel(String(localized: "End dictation session", comment: "VoiceOver label for the power button in the KeyVox Live Activity that ends the dictation session."))
    }
}

private struct KeyVoxLiveActivityButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .background(
                Circle()
                    .fill(Color(uiColor: .white).opacity(configuration.isPressed ? 0.10 : 0.2))
            )
    }
}

private func wordsThisWeekLabel(for weeklyWordCount: Int) -> String {
    String(localized: "\(weeklyWordCount) words this week!", comment: "Live Activity text for the number of words dictated this week. %lld is the word count; use plural forms.")
}

#Preview("Notification", as: .content, using: KeyVoxSessionLiveActivityAttributes()) {
    KeyVox_WidgetLiveActivity()
} contentStates: {
    KeyVoxSessionLiveActivityAttributes.ContentState(weeklyWordCount: 1284)
}
