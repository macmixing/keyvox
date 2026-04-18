import Foundation
import SwiftUI

struct ThirdPartyNoticesView: View {
    @Environment(\.appHaptics) private var appHaptics
    @Environment(\.dismiss) private var dismiss
    @State private var documentBlocks: [MarkdownBlock] = []

    private static let noticesResourceName = "THIRD_PARTY_NOTICES"

    var body: some View {
        ZStack {
            AppTheme.screenBackground
                .ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    ForEach(Array(documentBlocks.enumerated()), id: \.offset) { _, block in
                        blockView(for: block)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.top, 26)
                .padding(.horizontal, 20)
                .padding(.bottom, 32)
            }
            .scrollIndicators(.hidden)
            .textSelection(.enabled)
            .tint(.yellow)

            VStack {
                HStack {
                    Spacer()

                    Button(action: dismissSheet) {
                        Image(systemName: "xmark")
                            .font(.system(size: 25, weight: .semibold))
                            .foregroundStyle(.white.opacity(0.58))
                            .frame(width: 36, height: 36)
                            .background {
                                Color.clear
                                    .frame(width: 56, height: 56)
                            }
                            .contentShape(Rectangle())
                    }
                    .accessibilityLabel("Close")
                    .buttonStyle(.plain)
                    .padding(.top, 10)
                    .padding(.trailing, 12)
                }

                Spacer()
            }
        }
        .presentationDragIndicator(.hidden)
        .interactiveDismissDisabled()
        .onAppear(perform: loadDocumentBlocksIfNeeded)
    }

    @ViewBuilder
    private func blockView(for block: MarkdownBlock) -> some View {
        switch block {
        case .heading(let level, let text):
            Text(Self.attributedInlineText(from: text))
                .font(font(forHeadingLevel: level))
                .foregroundStyle(level == 1 ? .yellow : .white)
                .padding(.top, level == 1 ? 12 : 4)
                .frame(maxWidth: .infinity, alignment: .leading)
        case .paragraph(let text):
            Text(Self.attributedInlineText(from: text))
                .font(.appFont(15, variant: .light))
                .foregroundStyle(.white.opacity(0.82))
                .lineSpacing(5)
                .frame(maxWidth: .infinity, alignment: .leading)
        case .bullet(let text):
            HStack(alignment: .top, spacing: 10) {
                Text("•")
                    .font(.appFont(15))
                    .foregroundStyle(.yellow)

                Text(Self.attributedInlineText(from: text))
                    .font(.appFont(15, variant: .light))
                    .foregroundStyle(.white.opacity(0.82))
                    .lineSpacing(5)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    private func font(forHeadingLevel level: Int) -> Font {
        switch level {
        case 1:
            return .appFont(28, variant: .medium)
        case 2:
            return .appFont(22, variant: .medium)
        default:
            return .appFont(18, variant: .medium)
        }
    }

    private func dismissSheet() {
        appHaptics.light()
        dismiss()
    }

    private func loadDocumentBlocksIfNeeded() {
        guard documentBlocks.isEmpty else { return }
        documentBlocks = Self.loadDocumentBlocks()
    }

    private static func loadMarkdown() -> String? {
        guard let url = Bundle.main.url(forResource: noticesResourceName, withExtension: "md") else {
            return nil
        }

        return try? String(contentsOf: url, encoding: .utf8)
    }

    private static func attributedInlineText(from markdown: String) -> AttributedString {
        if let attributed = try? AttributedString(markdown: markdown) {
            return attributed
        }

        return AttributedString(markdown)
    }

    private static func loadDocumentBlocks() -> [MarkdownBlock] {
        guard let markdown = loadMarkdown() else {
            return [
                .paragraph("Third-party notices are currently unavailable.")
            ]
        }

        return MarkdownBlockParser.parse(markdown: markdown)
    }
}

private enum MarkdownBlock {
    case heading(level: Int, text: String)
    case paragraph(String)
    case bullet(String)
}

private enum MarkdownBlockParser {
    static func parse(markdown: String) -> [MarkdownBlock] {
        let lines = markdown.components(separatedBy: .newlines)
        var blocks: [MarkdownBlock] = []
        var paragraphLines: [String] = []

        func flushParagraphIfNeeded() {
            guard paragraphLines.isEmpty == false else { return }
            let paragraphText = paragraphLines
                .map { $0.trimmingCharacters(in: .whitespaces) }
                .joined(separator: " ")
                .trimmingCharacters(in: .whitespacesAndNewlines)

            if paragraphText.isEmpty == false {
                blocks.append(.paragraph(paragraphText))
            }

            paragraphLines.removeAll(keepingCapacity: true)
        }

        for line in lines {
            let trimmedLine = line.trimmingCharacters(in: .whitespaces)

            if trimmedLine.isEmpty {
                flushParagraphIfNeeded()
                continue
            }

            if let heading = parseHeading(from: trimmedLine) {
                flushParagraphIfNeeded()
                blocks.append(heading)
                continue
            }

            if let bullet = parseBullet(from: trimmedLine) {
                flushParagraphIfNeeded()
                blocks.append(.bullet(bullet))
                continue
            }

            paragraphLines.append(trimmedLine)
        }

        flushParagraphIfNeeded()
        return blocks
    }

    private static func parseHeading(from line: String) -> MarkdownBlock? {
        guard line.hasPrefix("#") else { return nil }

        let headingLevel = line.prefix { $0 == "#" }.count
        guard headingLevel > 0, headingLevel <= 6 else { return nil }

        let text = line.dropFirst(headingLevel).trimmingCharacters(in: .whitespaces)
        guard text.isEmpty == false else { return nil }

        return .heading(level: headingLevel, text: text)
    }

    private static func parseBullet(from line: String) -> String? {
        guard line.hasPrefix("- ") else { return nil }
        return String(line.dropFirst(2)).trimmingCharacters(in: .whitespaces)
    }
}
