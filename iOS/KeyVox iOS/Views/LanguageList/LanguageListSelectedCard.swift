import SwiftUI

/// The checked languages of a multiple-selection language list, in their order, under a
/// "Selected" heading. Each row's handle drags it to another place without unchecking anything;
/// VoiceOver moves a row up or down with its actions. Tapping a row unchecks it.
struct LanguageListSelectedCard: View {
    /// The checked languages, in order.
    let options: [LanguageListOption]
    /// The checked identifiers, in order, which reordering rewrites.
    @Binding var order: [String]
    let onUncheck: (LanguageListOption) -> Void

    @Environment(\.displayScale) private var displayScale
    @State private var draggedID: String?
    @State private var dragStartIndex = 0
    @State private var dragTranslation: CGFloat = 0
    @State private var rowHeight: CGFloat = 0

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Selected", comment: "Heading over the checked languages at the top of the keyboard language list, in the order the keyboard switches through them.")
                .font(.appFont(15, variant: .light))
                .foregroundStyle(.white.opacity(0.7))
                .padding(.horizontal, AppTheme.cardPadding)

            AppCard(
                contentInsets: EdgeInsets(
                    top: 0,
                    leading: AppTheme.cardPadding,
                    bottom: 4,
                    trailing: AppTheme.cardPadding
                )
            ) {
                VStack(spacing: 0) {
                    ForEach(Array(options.enumerated()), id: \.element.id) { index, option in
                        row(option, at: index)

                        if index < options.count - 1 {
                            Divider()
                                .overlay(.white.opacity(0.14))
                        }
                    }
                }
            }
        }
    }

    private func row(_ option: LanguageListOption, at index: Int) -> some View {
        let isDragged = draggedID == option.id
        return HStack(spacing: 12) {
            LanguageListRow(name: option.name, isChecked: true) {
                onUncheck(option)
            }
            .accessibilityActions {
                if index > 0 {
                    Button(String(localized: "Move Up", comment: "VoiceOver action on a selected keyboard language that moves it one place earlier in the switching order.")) {
                        move(option.id, to: index - 1)
                    }
                }
                if index < options.count - 1 {
                    Button(String(localized: "Move Down", comment: "VoiceOver action on a selected keyboard language that moves it one place later in the switching order.")) {
                        move(option.id, to: index + 1)
                    }
                }
            }

            Image(systemName: "line.3.horizontal")
                .font(.system(size: 17, weight: .medium))
                .foregroundStyle(.white.opacity(isDragged ? 0.9 : 0.5))
                .frame(width: 32, height: 44)
                .contentShape(Rectangle())
                .highPriorityGesture(dragGesture(for: option))
                .accessibilityHidden(true)
        }
        .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { height in
            rowHeight = height
        }
        .background(isDragged ? AppTheme.cardFill : Color.clear)
        .offset(y: isDragged ? dragOffset(currentIndex: index) : 0)
        .zIndex(isDragged ? 1 : 0)
        .transaction { transaction in
            if isDragged {
                transaction.animation = nil
            }
        }
    }

    /// The distance from one row to the next: a row and the divider under it.
    private var rowPitch: CGFloat {
        rowHeight + 1 / displayScale
    }

    private func dragOffset(currentIndex: Int) -> CGFloat {
        dragTranslation - CGFloat(currentIndex - dragStartIndex) * rowPitch
    }

    private func dragGesture(for option: LanguageListOption) -> some Gesture {
        DragGesture(minimumDistance: 0, coordinateSpace: .global)
            .onChanged { value in
                if draggedID == nil {
                    draggedID = option.id
                    dragStartIndex = order.firstIndex(of: option.id) ?? 0
                }
                dragTranslation = value.translation.height
                guard rowPitch > 0 else { return }
                let steps = Int((dragTranslation / rowPitch).rounded())
                let target = min(max(dragStartIndex + steps, 0), order.count - 1)
                if order.firstIndex(of: option.id) != target {
                    withAnimation(.easeInOut(duration: 0.15)) {
                        move(option.id, to: target)
                    }
                }
            }
            .onEnded { _ in
                withAnimation(.easeOut(duration: 0.15)) {
                    draggedID = nil
                    dragTranslation = 0
                }
            }
    }

    private func move(_ identifier: String, to target: Int) {
        guard let current = order.firstIndex(of: identifier), current != target else { return }
        order.remove(at: current)
        order.insert(identifier, at: target)
    }
}
