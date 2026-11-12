import Foundation
import SwiftUI
import KeyVoxStyleRewrite

struct SettingsVibesExamplesSection: View {
    @Binding var selectedVibe: StyleRewriteStyle
    let displayedSelectedVibe: StyleRewriteStyle
    let dictationModel: StyleRewriteDictationModel
    let isSelectionEnabled: Bool
    let isDownloadRequired: Bool

    @State private var isExpanded = false
    @State private var expandedContentHeight: CGFloat = 0
    @State private var didAttemptUnavailableSelection = false

    private static let expansionAnimation = Animation.spring(response: 0.42, dampingFraction: 0.84)

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .top, spacing: 12) {
                Text(summaryText)
                    .font(.appFont(15, variant: .light))
                    .foregroundStyle(summaryColor)
                    .frame(maxWidth: .infinity, alignment: .leading)

                Button {
                    withAnimation(Self.expansionAnimation) {
                        isExpanded.toggle()
                    }
                } label: {
                    Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                        .font(.system(size: 28, weight: .heavy))
                        .foregroundStyle(.yellow)
                        .frame(width: 56, height: 56)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(
                    isExpanded
                    ? SettingsVibesExamplesCopy.hideExamplesAccessibilityLabel
                    : SettingsVibesExamplesCopy.showExamplesAccessibilityLabel
                )
            }

            expandedContent
                .frame(height: isExpanded ? expandedContentHeight : 0, alignment: .top)
                .clipped()
                .allowsHitTesting(isExpanded)
                .accessibilityHidden(!isExpanded)
                .background(alignment: .top) {
                    if isExpanded || expandedContentHeight == 0 {
                        expandedContentMeasurement
                    }
                }
        }
        .onChange(of: isDownloadRequired) { downloadRequired in
            if downloadRequired == false {
                didAttemptUnavailableSelection = false
            }
        }
    }

    private var expandedContent: some View {
        VStack(alignment: .leading, spacing: 16) {
            Divider()
                .overlay(.white.opacity(0.22))

            VStack(alignment: .leading, spacing: 14) {
                ForEach(Array(examples.enumerated()), id: \.element.style) { index, example in
                    exampleRow(example)

                    if index < examples.count - 1 {
                        Divider()
                            .overlay(.white.opacity(0.22))
                            .padding(.leading, 12)
                            .padding(.trailing, 12)
                    }
                }
            }

            Text(StyleRewriteStyle.languageSupportNote)
                .font(.appFont(13, variant: .light))
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .center)
        }
    }

    private var expandedContentMeasurement: some View {
        expandedContent
            .fixedSize(horizontal: false, vertical: true)
            .hidden()
            .allowsHitTesting(false)
            .accessibilityHidden(true)
            .background(
                GeometryReader { geometry in
                    Color.clear
                        .onAppear {
                            updateExpandedContentHeight(geometry.size.height)
                        }
                        .onChange(of: geometry.size.height) { newHeight in
                            updateExpandedContentHeight(newHeight)
                        }
                }
            )
    }

    private func exampleRow(_ example: VibeExample) -> some View {
        Button {
            guard isSelectionEnabled else {
                if isDownloadRequired {
                    didAttemptUnavailableSelection = true
                }
                return
            }
            selectedVibe = example.style
        } label: {
            HStack(alignment: .center, spacing: 8) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(example.style.displayName)
                        .font(.appFont(17))
                        .foregroundStyle(.yellow)
                        .lineLimit(1)
                        .fixedSize(horizontal: true, vertical: false)

                    Text(example.text)
                        .font(.appFont(15, variant: .light))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                Image(systemName: example.style == displayedSelectedVibe ? "checkmark.circle.fill" : "checkmark.circle.dotted")
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(example.style == displayedSelectedVibe ? .green : .white)
            }
            .padding(.leading, 10)
            .padding(.trailing, 15)
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .buttonStyle(.plain)
    }

    private func updateExpandedContentHeight(_ newHeight: CGFloat) {
        guard abs(expandedContentHeight - newHeight) > 0.5 else { return }
        expandedContentHeight = newHeight
    }

    private var examples: [VibeExample] {
        StyleRewriteStyle.allCases.map { style in
            VibeExample(style: style, text: style.exampleText(for: dictationModel))
        }
    }

    private var summaryText: String {
        guard isDownloadRequired else {
            return displayedSelectedVibe.description
        }

        return didAttemptUnavailableSelection
            ? SettingsVibesExamplesCopy.downloadRequiredSelectionPrompt
            : SettingsVibesExamplesCopy.unavailableStylesPrompt
    }

    private var summaryColor: Color {
        didAttemptUnavailableSelection && isDownloadRequired
            ? .yellow
            : .white.opacity(0.7)
    }

    private struct VibeExample: Hashable {
        let style: StyleRewriteStyle
        let text: String
    }
}

enum SettingsVibesExamplesCopy {
    static let showExamplesAccessibilityLabel = String(localized: "Show vibe examples", comment: "VoiceOver label for the button that expands the Vibes examples on the KeyVox Vibes card in Settings. Vibe is a brand name and stays in English.")
    static let hideExamplesAccessibilityLabel = String(localized: "Hide vibe examples", comment: "VoiceOver label for the button that collapses the Vibes examples on the KeyVox Vibes card in Settings. Vibe is a brand name and stays in English.")
    static let unavailableStylesPrompt = String(localized: "Check out the reversible writing styles available with KeyVox Vibes.", comment: "Summary on the KeyVox Vibes card in Settings before the Vibes model is installed. KeyVox Vibes is a brand name and stays in English.")
    static let downloadRequiredSelectionPrompt = String(localized: "Click Download to install Vibes AI to before selecting a style.", comment: "Prompt on the KeyVox Vibes card in Settings when a style is clicked before the Vibes model is installed. Download is the card's Download button; translate it the same way as that button. Vibes AI is a brand name and stays in English.")
}
