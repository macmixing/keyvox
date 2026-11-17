import Foundation
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
            Button(String(localized: "Copy", comment: "Context menu button that copies a Dictionary entry."), systemImage: "doc.on.doc") {
                UIPasteboard.general.string = entry.phrase
            }
            .tint(.white)

            Button(String(localized: "Edit", comment: "Context menu button that edits a Dictionary entry."), systemImage: "pencil", action: onEdit)
                .tint(.white)

            Button(role: .destructive) {
                isDeleteConfirmationPresented = true
            }
            label: {
                Label(String(localized: "Delete", comment: "Context menu button that deletes a Dictionary entry."), systemImage: "trash")
            }
            .tint(.red)
        }
        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
            Button(String(localized: "Delete", comment: "Swipe action that deletes a Dictionary entry."), systemImage: "trash") {
                isDeleteConfirmationPresented = true
            }
            .tint(.red)

            Button(String(localized: "Edit", comment: "Swipe action that edits a Dictionary entry."), systemImage: "pencil", action: onEdit)
                .tint(AppTheme.accent)
        }
        .confirmationDialog(
            String(localized: "Delete Entry?", comment: "Title of the confirmation shown before deleting a Dictionary entry."),
            isPresented: $isDeleteConfirmationPresented,
            titleVisibility: .visible
        ) {
            Button(String(localized: "Delete Entry", comment: "Destructive button in the confirmation that deletes a Dictionary entry."), role: .destructive, action: onDelete)
            Button(String(localized: "Cancel", comment: "Button that closes the Dictionary entry delete confirmation without deleting."), role: .cancel) {}
        } message: {
            Text("This dictionary entry will be removed from KeyVox.", comment: "Message in the confirmation shown before deleting a Dictionary entry. KeyVox is a brand name and stays in English.")
        }
        .blocksAppReviewRequest(isDeleteConfirmationPresented)
    }
}
