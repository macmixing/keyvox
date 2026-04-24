import Foundation
import Combine

public enum DictionaryStoreError: LocalizedError, Equatable {
    case emptyPhrase
    case duplicatePhrase
    case invalidSnapshotImport
    case saveFailed

    public var errorDescription: String? {
        switch self {
        case .emptyPhrase:
            return "Please enter a word or phrase."
        case .duplicatePhrase:
            return "That word is already in your dictionary."
        case .invalidSnapshotImport:
            return "The synced dictionary data was invalid and could not be applied."
        case .saveFailed:
            return "Couldn't save dictionary to disk. Please try again."
        }
    }
}

@MainActor
public final class DictionaryStore: ObservableObject {
    @Published public private(set) var entries: [DictionaryEntry] = []
    @Published public private(set) var loadWarningMessage: String?
    @Published public private(set) var saveErrorMessage: String?
    @Published public private(set) var degradedDurability: Bool = false
    public private(set) var persistedSnapshotModifiedAt: Date?

    private struct DictionaryPayload: Codable {
        let version: Int
        let entries: [DictionaryEntry]
    }

    private let fileManager: FileManager
    private let appSupportDirectoryURL: URL
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    public init(fileManager: FileManager = .default, baseDirectoryURL: URL) {
        self.fileManager = fileManager
        self.appSupportDirectoryURL = baseDirectoryURL
        loadFromDisk()
    }

    // Keep teardown explicit to avoid synthesized deinit runtime issues in test host.
    deinit {}

    public func add(phrase: String) throws {
        let cleanedPhrase = normalizeInput(phrase)
        guard !cleanedPhrase.isEmpty else {
            throw DictionaryStoreError.emptyPhrase
        }
        guard !containsDuplicate(cleanedPhrase, excluding: nil) else {
            throw DictionaryStoreError.duplicatePhrase
        }

        var candidateEntries = entries
        candidateEntries.append(DictionaryEntry(phrase: cleanedPhrase))
        try persistAfterMutation(candidateEntries)
        entries = candidateEntries
    }

    public func update(id: UUID, phrase: String) throws {
        guard let index = entries.firstIndex(where: { $0.id == id }) else { return }

        let cleanedPhrase = normalizeInput(phrase)
        guard !cleanedPhrase.isEmpty else {
            throw DictionaryStoreError.emptyPhrase
        }
        guard !containsDuplicate(cleanedPhrase, excluding: id) else {
            throw DictionaryStoreError.duplicatePhrase
        }

        var candidateEntries = entries
        candidateEntries[index].phrase = cleanedPhrase
        try persistAfterMutation(candidateEntries)
        entries = candidateEntries
    }

    public func delete(id: UUID) {
        guard let index = entries.firstIndex(where: { $0.id == id }) else { return }
        var candidateEntries = entries
        candidateEntries.remove(at: index)

        do {
            try persist(entries: candidateEntries)
            entries = candidateEntries
        } catch {
            saveErrorMessage = DictionaryStoreError.saveFailed.localizedDescription
        }
    }

    public func replaceAll(entries newEntries: [DictionaryEntry]) throws {
        let candidateEntries = try validatedSnapshotEntries(newEntries)
        try persistAfterMutation(candidateEntries)
        entries = candidateEntries
    }

    public func whisperHintPrompt(maxEntries: Int = 200, maxChars: Int = 1200) -> String {
        DictionaryHintPromptBuilder.prompt(for: entries, maxEntries: maxEntries, maxChars: maxChars)
    }

    public func clearWarnings() {
        loadWarningMessage = nil
        saveErrorMessage = nil
    }

    private var dictionaryDirectoryURL: URL {
        appSupportDirectoryURL.appendingPathComponent("Dictionary", isDirectory: true)
    }

    private var dictionaryFileURL: URL {
        dictionaryDirectoryURL.appendingPathComponent("dictionary.json")
    }

    private var backupFileURL: URL {
        dictionaryDirectoryURL.appendingPathComponent("dictionary.backup.json")
    }

    private var degradedDurabilityMarkerURL: URL {
        dictionaryDirectoryURL.appendingPathComponent("dictionary.backup.degraded")
    }

    private func loadFromDisk() {
        saveErrorMessage = nil
        degradedDurability = fileManager.fileExists(atPath: degradedDurabilityMarkerURL.path)
        persistedSnapshotModifiedAt = nil

        let hasPrimary = fileManager.fileExists(atPath: dictionaryFileURL.path)
        let hasBackup = fileManager.fileExists(atPath: backupFileURL.path)

        guard hasPrimary || hasBackup else {
            entries = []
            loadWarningMessage = nil
            clearDegradedDurabilityMarker()
            return
        }

        if hasPrimary, let payload = try? readPayload(from: dictionaryFileURL) {
            entries = payload.entries
            persistedSnapshotModifiedAt = fileModificationDate(at: dictionaryFileURL)
            loadWarningMessage = nil
            return
        }

        if hasBackup, let backupPayload = try? readPayload(from: backupFileURL) {
            entries = backupPayload.entries
            persistedSnapshotModifiedAt = fileModificationDate(at: backupFileURL)
            loadWarningMessage = "Dictionary was recovered from backup after a file issue."

            do {
                try persist(entries: backupPayload.entries, updatePersistedSnapshotModifiedAt: false)
                // Keep this warning visible until the user performs the next save action.
                loadWarningMessage = "Dictionary was recovered from backup after a file issue."
            } catch {
                saveErrorMessage = DictionaryStoreError.saveFailed.localizedDescription
            }
            return
        }

        quarantineIfPresent(dictionaryFileURL)
        quarantineIfPresent(backupFileURL)

        entries = []
        persistedSnapshotModifiedAt = nil
        loadWarningMessage = "Dictionary data was corrupted and reset."
    }

    private func persistAfterMutation(_ candidateEntries: [DictionaryEntry]) throws {
        do {
            try persist(entries: candidateEntries)
        } catch {
            saveErrorMessage = DictionaryStoreError.saveFailed.localizedDescription
            throw DictionaryStoreError.saveFailed
        }
    }

    private func persist(
        entries candidateEntries: [DictionaryEntry],
        updatePersistedSnapshotModifiedAt: Bool = true
    ) throws {
        try fileManager.createDirectory(at: dictionaryDirectoryURL, withIntermediateDirectories: true)

        let payload = DictionaryPayload(version: 1, entries: candidateEntries)
        let data = try encoder.encode(payload)

        try data.write(to: dictionaryFileURL, options: .atomic)
        do {
            try data.write(to: backupFileURL, options: .atomic)
            clearDegradedDurabilityMarker()
        } catch {
            markDegradedDurability()
        }

        if updatePersistedSnapshotModifiedAt {
            persistedSnapshotModifiedAt = fileModificationDate(at: dictionaryFileURL)
        }

        saveErrorMessage = nil
        loadWarningMessage = nil
    }

    private func markDegradedDurability() {
        degradedDurability = true
        let marker = Data("backup-write-failed".utf8)
        do {
            try marker.write(to: degradedDurabilityMarkerURL, options: .atomic)
        } catch {
            #if DEBUG
            print("[DictionaryStore] Failed to persist degraded durability marker: \(error)")
            #endif
        }
    }

    private func clearDegradedDurabilityMarker() {
        degradedDurability = false

        guard fileManager.fileExists(atPath: degradedDurabilityMarkerURL.path) else { return }
        do {
            try fileManager.removeItem(at: degradedDurabilityMarkerURL)
        } catch {
            #if DEBUG
            print("[DictionaryStore] Failed to clear degraded durability marker: \(error)")
            #endif
        }
    }

    private func readPayload(from fileURL: URL) throws -> DictionaryPayload {
        let data = try Data(contentsOf: fileURL)
        return try decoder.decode(DictionaryPayload.self, from: data)
    }

    private func fileModificationDate(at fileURL: URL) -> Date? {
        guard let attributes = try? fileManager.attributesOfItem(atPath: fileURL.path) else {
            return nil
        }

        return attributes[.modificationDate] as? Date
    }

    private func quarantineIfPresent(_ fileURL: URL) {
        guard fileManager.fileExists(atPath: fileURL.path) else { return }

        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd-HHmmss"
        let timestamp = formatter.string(from: Date())
        let quarantinedURL = fileURL.deletingPathExtension()
            .appendingPathExtension("corrupt.\(timestamp).json")

        do {
            if fileManager.fileExists(atPath: quarantinedURL.path) {
                try fileManager.removeItem(at: quarantinedURL)
            }
            try fileManager.moveItem(at: fileURL, to: quarantinedURL)
        } catch {
            #if DEBUG
            print("[DictionaryStore] Failed to quarantine file: \(fileURL.lastPathComponent), error: \(error)")
            #endif
        }
    }

    private func normalizeInput(_ phrase: String) -> String {
        phrase
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
    }

    private func containsDuplicate(_ phrase: String, excluding id: UUID?) -> Bool {
        let key = dedupeKey(for: phrase)
        return entries.contains { entry in
            if let id, entry.id == id {
                return false
            }
            return dedupeKey(for: entry.phrase) == key
        }
    }

    private func dedupeKey(for phrase: String) -> String {
        DictionaryTextNormalization.normalizedPhrase(normalizeInput(phrase))
    }

    private func validatedSnapshotEntries(_ sourceEntries: [DictionaryEntry]) throws -> [DictionaryEntry] {
        let sanitized = sanitizedEntries(sourceEntries)
        guard sanitized.count == sourceEntries.count else {
            throw DictionaryStoreError.invalidSnapshotImport
        }

        for (original, cleaned) in zip(sourceEntries, sanitized) {
            guard original.id == cleaned.id, original.phrase == cleaned.phrase else {
                throw DictionaryStoreError.invalidSnapshotImport
            }
        }

        return sanitized
    }

    private func sanitizedEntries(_ sourceEntries: [DictionaryEntry]) -> [DictionaryEntry] {
        var seenKeys = Set<String>()
        var result: [DictionaryEntry] = []

        for entry in sourceEntries {
            let cleanedPhrase = normalizeInput(entry.phrase)
            guard !cleanedPhrase.isEmpty else { continue }

            let key = dedupeKey(for: cleanedPhrase)
            guard seenKeys.insert(key).inserted else { continue }

            result.append(DictionaryEntry(id: entry.id, phrase: cleanedPhrase))
        }

        return result
    }
}
