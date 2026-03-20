import SwiftUI
import KeyVoxCore

enum DictionarySortMode: String, CaseIterable, Identifiable {
    case alphabetical = "A-Z"
    case recentlyAdded = "Recently Added"

    var id: Self { self }
}

extension SettingsView {
    var dictionarySettings: some View {
        VStack(alignment: .leading, spacing: 10) {

            SettingsCard {
                VStack(alignment: .leading, spacing: 12) {
                    HStack(alignment: .center, spacing: 12) {
                        ZStack {
                            RoundedRectangle(cornerRadius: 12)
                                .fill(MacAppTheme.iconFill)
                                .frame(width: 44, height: 44)

                            Image(systemName: "text.book.closed.fill")
                                .font(.appFont(20))
                                .foregroundColor(MacAppTheme.accent)
                        }

                        VStack(alignment: .leading, spacing: 4) {
                            Text("Dictionary")
                                .font(.appFont(17))

                            Text("Add custom words, email addresses, and short phrases to improve transcription accuracy.")
                                .font(.appFont(12, variant: .light))
                                .foregroundColor(.secondary)
                                .lineSpacing(2)
                        }
                    }

                    if let warning = dictionaryStore.loadWarningMessage {
                        Text(warning)
                            .font(.appFont(11))
                            .foregroundColor(.red)
                            .multilineTextAlignment(.center)
                            .frame(maxWidth: .infinity, alignment: .center)
                    }

                    if let saveError = dictionaryStore.saveErrorMessage {
                        Text(saveError)
                            .font(.appFont(11))
                            .foregroundColor(.red)
                            .multilineTextAlignment(.center)
                            .frame(maxWidth: .infinity, alignment: .center)
                    }

                    let displayedEntries = dictionarySortMode == .alphabetical
                        ? dictionaryStore.entries.sorted {
                            let order = $0.phrase.localizedCaseInsensitiveCompare($1.phrase)
                            if order == .orderedSame {
                                return $0.id.uuidString < $1.id.uuidString
                            }
                            return order == .orderedAscending
                        }
                        : Array(dictionaryStore.entries.reversed())

                    if displayedEntries.isEmpty {
                        Text("No custom words added yet.")
                            .font(.appFont(12, variant: .light))
                            .foregroundColor(.secondary)
                    } else {
                        HStack {
                            Spacer()
                            Picker("", selection: $dictionarySortMode) {
                                ForEach(DictionarySortMode.allCases) { mode in
                                    Text(mode.rawValue).tag(mode)
                                }
                            }
                            .pickerStyle(.segmented)
                            .frame(width: 220)
                            .controlSize(.small)
                            .labelsHidden()
                            Spacer()
                        }

                        VStack(spacing: 8) {
                            ForEach(displayedEntries) { entry in
                                DictionaryEntryRow(
                                    entry: entry,
                                    onEdit: { dictionaryEditorMode = .edit(entry) },
                                    onDelete: { dictionaryDeleteTarget = entry }
                                )
                            }
                        }
                    }
                }
            }
        }
    }
}

private struct DictionaryEntryRow: View {
    let entry: DictionaryEntry
    let onEdit: () -> Void
    let onDelete: () -> Void

    @State private var isHovered = false
    @State private var isEditHovered = false
    @State private var isDeleteHovered = false

    var body: some View {
        HStack(spacing: 12) {
            Text(entry.phrase)
                .font(.appFont(13, variant: .light))
                .foregroundColor(.white)
                .lineLimit(1)

            Spacer(minLength: 12)

            HStack(spacing: 10) {
                Button(action: onEdit) {
                    Image(systemName: "pencil")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(.white.opacity(isEditHovered ? 1.0 : 0.88))
                }
                .buttonStyle(.plain)
                .onHover { isEditHovered = $0 }

                Button(action: onDelete) {
                    Image(systemName: "trash")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.red.opacity(isDeleteHovered ? 1.0 : 0.88))
                }
                .buttonStyle(.plain)
                .onHover { isDeleteHovered = $0 }
            }
            .opacity(isHovered ? 1 : 0)
            .allowsHitTesting(isHovered)
            .animation(.easeInOut(duration: 0.12), value: isHovered)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 9)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(isHovered ? MacAppTheme.rowPressedFill : MacAppTheme.rowFill)
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(isHovered ? MacAppTheme.rowPressedStroke : MacAppTheme.rowStroke, lineWidth: 1)
                )
        )
        .onHover { isHovered = $0 }
    }
}
