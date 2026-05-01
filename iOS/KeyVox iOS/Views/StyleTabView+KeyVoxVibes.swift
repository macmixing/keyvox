import SwiftUI
import KeyVoxStyleRewrite

extension StyleTabView {
    @ViewBuilder
    var keyVoxVibesSection: some View {
        AppCard {
            VStack(alignment: .leading, spacing: 16) {
                HStack(alignment: .top, spacing: 12) {
                    ZStack {
                        Circle()
                            .fill(AppTheme.accent.opacity(0.4))
                            .frame(width: 32, height: 32)

                        Image(systemName: "wand.and.sparkles")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.yellow)
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        Text("KeyVox Vibes")
                            .font(.appFont(18))
                            .foregroundStyle(.white)

                        Text(settingsStore.selectedVibe.displayName)
                            .font(.appFont(17))
                            .foregroundStyle(.yellow)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)

                    Menu {
                        Picker("", selection: keyVoxVibesSelection) {
                            ForEach(StyleRewriteStyle.allCases) { style in
                                Text(style.displayName).tag(style)
                            }
                        }
                        .pickerStyle(.inline)
                    } label: {
                        Text("Change")
                            .font(.appFont(16))
                            .foregroundStyle(.yellow)
                    }
                    .padding(.top, 2)
                }

                Divider()
                    .overlay(.white.opacity(0.22))

                HStack(alignment: .top, spacing: 12) {
                    Text(keyVoxVibesDescription)
                        .font(.appFont(15, variant: .light))
                        .foregroundStyle(.white.opacity(0.7))
                        .frame(maxWidth: .infinity, alignment: .leading)

                    Button {
                        appHaptics.light()
                        withAnimation(Self.sectionExpansionAnimation) {
                            isVibeExamplesExpanded.toggle()
                        }
                    } label: {
                        Image(systemName: isVibeExamplesExpanded ? "chevron.down" : "chevron.right")
                            .font(.system(size: 28, weight: .heavy))
                            .foregroundStyle(.yellow)
                            .frame(width: 56, height: 56)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(isVibeExamplesExpanded ? "Hide vibe examples" : "Show vibe examples")
                }

                vibeExamplesExpandedContent
                    .frame(height: isVibeExamplesExpanded ? vibeExamplesExpandedContentHeight : 0, alignment: .top)
                    .clipped()
                    .allowsHitTesting(isVibeExamplesExpanded)
                    .accessibilityHidden(!isVibeExamplesExpanded)
                    .background(alignment: .top) {
                        if isVibeExamplesExpanded || vibeExamplesExpandedContentHeight == 0 {
                            vibeExamplesExpandedContentMeasurement
                        }
                    }
            }
        }
    }

    private var vibeExamplesExpandedContent: some View {
        VStack(alignment: .leading, spacing: 16) {
            Divider()
                .overlay(.white.opacity(0.22))

            VStack(alignment: .leading, spacing: 14) {
                ForEach(Array(vibeExamples.enumerated()), id: \.element.style) { index, example in
                    vibeExampleRow(example)

                    if index < vibeExamples.count - 1 {
                        Divider()
                            .overlay(.white.opacity(0.22))
                            .padding(.leading, 12)
                            .padding(.trailing, 12)
                    }
                }
            }
        }
    }

    private var vibeExamplesExpandedContentMeasurement: some View {
        vibeExamplesExpandedContent
            .fixedSize(horizontal: false, vertical: true)
            .hidden()
            .allowsHitTesting(false)
            .accessibilityHidden(true)
            .background(
                GeometryReader { geometry in
                    Color.clear
                        .onAppear {
                            updateVibeExamplesExpandedContentHeight(geometry.size.height)
                        }
                        .onChange(of: geometry.size.height) { _, newHeight in
                            updateVibeExamplesExpandedContentHeight(newHeight)
                        }
                }
            )
    }

    private func vibeExampleRow(_ example: VibeExample) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(example.style.displayName)
                .font(.appFont(17))
                .foregroundStyle(.white)
                .lineLimit(1)
                .fixedSize(horizontal: true, vertical: false)

            Text(example.text)
                .font(.appFont(15, variant: .light))
                .foregroundStyle(.yellow)
                .frame(maxWidth: .infinity, alignment: .leading)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.horizontal, 10)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func updateVibeExamplesExpandedContentHeight(_ newHeight: CGFloat) {
        guard abs(vibeExamplesExpandedContentHeight - newHeight) > 0.5 else { return }
        vibeExamplesExpandedContentHeight = newHeight
    }

    private var vibeExamples: [VibeExample] {
        StyleRewriteStyle.allCases.map { style in
            VibeExample(style: style, text: style.exampleText)
        }
    }

    private struct VibeExample: Hashable {
        let style: StyleRewriteStyle
        let text: String
    }

    private var keyVoxVibesDescription: String {
        settingsStore.selectedVibe.description
    }

    private var keyVoxVibesSelection: Binding<StyleRewriteStyle> {
        Binding(
            get: { settingsStore.selectedVibe },
            set: { newValue in
                settingsStore.selectedVibe = newValue
            }
        )
    }
}
