import SwiftUI
import KeyVoxStyleRewrite

struct SettingsVibesExamplesSection: View {
    @Binding var selectedVibe: StyleRewriteStyle
    let displayedSelectedVibe: StyleRewriteStyle
    let isSelectionEnabled: Bool

    @State private var isExpanded = false
    @State private var expandedContentHeight: CGFloat = 0

    private static let expansionAnimation = Animation.spring(response: 0.42, dampingFraction: 0.84)

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .top, spacing: 12) {
                Text(displayedSelectedVibe.description)
                    .font(.appFont(15, variant: .light))
                    .foregroundStyle(.white.opacity(0.7))
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
            guard isSelectionEnabled else { return }
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
            VibeExample(style: style, text: style.exampleText)
        }
    }

    private struct VibeExample: Hashable {
        let style: StyleRewriteStyle
        let text: String
    }
}

enum SettingsVibesExamplesCopy {
    static let showExamplesAccessibilityLabel = "Show vibe examples"
    static let hideExamplesAccessibilityLabel = "Hide vibe examples"
}
