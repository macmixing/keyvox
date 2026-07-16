import KeyVoxCore
import SwiftUI

struct MacFormattingPillView: View {
    let kind: DictationDeterministicControlKind
    let isEnabled: Bool
    let state: OverlayPillState

    var body: some View {
        OverlayPillView(
            title: title,
            state: state,
            contentSpacing: contentSpacing
        ) {
            Image(systemName: symbolName)
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(isEnabled ? Color.yellow : Color.white)
                .accessibilityHidden(true)
        }
    }

    private var title: String {
        switch kind {
        case .paragraphs:
            return "Paragraph"
        case .lists:
            return "List"
        }
    }

    private var symbolName: String {
        switch kind {
        case .paragraphs:
            return "text.alignleft"
        case .lists:
            return "list.number"
        }
    }

    private var contentSpacing: CGFloat {
        switch kind {
        case .paragraphs:
            OverlayPillMetrics.paragraphContentSpacing
        case .lists:
            OverlayPillMetrics.contentSpacing
        }
    }
}
