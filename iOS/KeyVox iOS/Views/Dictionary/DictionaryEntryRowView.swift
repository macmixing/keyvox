import SwiftUI
import UIKit
import KeyVoxCore

struct DictionaryEntryRowView: View {
    private enum Layout {
        static let contentMinHeight: CGFloat = 44
        static let horizontalPadding: CGFloat = 22
        static let verticalPadding: CGFloat = 9
    }

    let entry: DictionaryEntry
    let onEdit: () -> Void
    let onDelete: () -> Void

    @State private var isDeleteConfirmationPresented = false

    var body: some View {
        HStack(spacing: 12) {
            Text(entry.phrase)
                .font(.appFont(18.4, variant: .light))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity, alignment: .leading)
                .multilineTextAlignment(.leading)
        }
        .frame(minHeight: Layout.contentMinHeight)
        .padding(.horizontal, Layout.horizontalPadding)
        .padding(.vertical, Layout.verticalPadding)
        .background(
            RoundedRectangle(cornerRadius: AppTheme.rowCornerRadius)
                .fill(AppTheme.rowFill)
                .overlay(
                    RoundedRectangle(cornerRadius: AppTheme.rowCornerRadius)
                        .stroke(AppTheme.rowStroke, lineWidth: 1)
                )
        )
        .contextMenu {
            Button("Copy", systemImage: "doc.on.doc") {
                UIPasteboard.general.string = entry.phrase
            }
            .tint(.white)

            Button("Edit", systemImage: "pencil", action: onEdit)
                .tint(.white)

            Button(role: .destructive) {
                isDeleteConfirmationPresented = true
            }
            label: {
                Label("Delete", systemImage: "trash")
            }
            .tint(.red)
        }
        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
            Button("Delete", systemImage: "trash") {
                isDeleteConfirmationPresented = true
            }
            .tint(.red)

            Button("Edit", systemImage: "pencil", action: onEdit)
                .tint(AppTheme.accent)
        }
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
