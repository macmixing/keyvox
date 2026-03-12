import SwiftUI
import KeyVoxCore

struct DictionaryEntryRowView: View {
    let entry: DictionaryEntry
    let onEdit: () -> Void
    let onDelete: () -> Void

    @State private var isDeleteConfirmationPresented = false

    var body: some View {
        HStack(spacing: 12) {
            Text(entry.phrase)
                .font(.appFont(13))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity, alignment: .leading)
                .multilineTextAlignment(.leading)

            Menu {
                Button("Edit", systemImage: "pencil", action: onEdit)
                    .tint(.white)

                Button("Delete", systemImage: "trash", role: .destructive) {
                    isDeleteConfirmationPresented = true
                }
                .tint(.red)
            } label: {
                Image(systemName: "ellipsis")
                    .font(.system(size: 24, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.88))
                    .frame(width: 44, height: 44)
                    .contentShape(Rectangle())
            }
            .accessibilityLabel("Actions")
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 9)
        .background(
            RoundedRectangle(cornerRadius: iOSAppTheme.rowCornerRadius)
                .fill(iOSAppTheme.rowFill)
                .overlay(
                    RoundedRectangle(cornerRadius: iOSAppTheme.rowCornerRadius)
                        .stroke(iOSAppTheme.rowStroke, lineWidth: 1)
                )
        )
        .confirmationDialog(
            "Delete Entry?",
            isPresented: $isDeleteConfirmationPresented,
            titleVisibility: .visible
        ) {
            Button("Delete Entry", role: .destructive, action: onDelete)
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This dictionary entry will be removed from KeyVox.")
        }
    }
}
