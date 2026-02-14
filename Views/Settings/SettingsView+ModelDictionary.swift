import SwiftUI

extension SettingsView {
    var dictionarySettings: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("DICTIONARY")
                .font(.custom("Kanit Medium", size: 10))
                .foregroundColor(.secondary.opacity(0.6))
                .padding(.leading, 4)

            SettingsCard {
                VStack(alignment: .leading, spacing: 12) {
                    HStack(alignment: .center, spacing: 12) {
                        ZStack {
                            RoundedRectangle(cornerRadius: 12)
                                .fill(Color.indigo.opacity(0.15))
                                .frame(width: 44, height: 44)

                            Image(systemName: "text.book.closed.fill")
                                .font(.custom("Kanit Medium", size: 20))
                                .foregroundColor(.indigo)
                        }

                        VStack(alignment: .leading, spacing: 4) {
                            Text("Dictionary")
                                .font(.custom("Kanit Medium", size: 17))

                            Text("Add custom words and phrases to improve transcription consistency.")
                                .font(.custom("Kanit Medium", size: 12))
                                .foregroundColor(.secondary)
                                .lineSpacing(2)
                        }

                        Spacer(minLength: 16)

                        Button("Add Word") {
                            dictionaryEditorMode = .add
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(.indigo)
                        .controlSize(.small)
                    }

                    if let warning = dictionaryStore.loadWarningMessage {
                        Text(warning)
                            .font(.custom("Kanit Medium", size: 11))
                            .foregroundColor(.red)
                    }

                    if let saveError = dictionaryStore.saveErrorMessage {
                        Text(saveError)
                            .font(.custom("Kanit Medium", size: 11))
                            .foregroundColor(.red)
                    }

                    if dictionaryStore.entries.isEmpty {
                        Text("No custom words added yet.")
                            .font(.custom("Kanit Medium", size: 12))
                            .foregroundColor(.secondary)
                    } else {
                        VStack(spacing: 8) {
                            ForEach(dictionaryStore.entries) { entry in
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

    var body: some View {
        HStack(spacing: 12) {
            Text(entry.phrase)
                .font(.custom("Kanit Medium", size: 13))
                .foregroundColor(.white)
                .lineLimit(1)

            Spacer(minLength: 12)

            HStack(spacing: 10) {
                Button(action: onEdit) {
                    Image(systemName: "pencil")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)

                Button(action: onDelete) {
                    Image(systemName: "trash")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.red.opacity(0.9))
                }
                .buttonStyle(.plain)
            }
            .opacity(isHovered ? 1 : 0)
            .allowsHitTesting(isHovered)
            .animation(.easeInOut(duration: 0.12), value: isHovered)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 9)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color.white.opacity(isHovered ? 0.08 : 0.04))
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(Color.white.opacity(isHovered ? 0.14 : 0.08), lineWidth: 1)
                )
        )
        .onHover { isHovered = $0 }
    }
}
