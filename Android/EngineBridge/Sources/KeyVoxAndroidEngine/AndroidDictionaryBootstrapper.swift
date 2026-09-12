import Foundation
import KeyVoxCore

@MainActor
enum AndroidDictionaryBootstrapper {
    private static let markerName = "dictionary.initial-entry-bootstrap-v1"

    static func bootstrap(store: DictionaryStore, baseDirectoryURL: URL) {
        let dictionaryDirectory = baseDirectoryURL.appendingPathComponent("Dictionary", isDirectory: true)
        let markerURL = dictionaryDirectory.appendingPathComponent(markerName)
        guard FileManager.default.fileExists(atPath: markerURL.path) == false else { return }

        do {
            if store.persistedSnapshotModifiedAt == nil,
               store.loadWarningMessage == nil,
               store.entries.isEmpty {
                try store.replaceAll(entries: [DictionaryInitialEntries.keyVox])
            }

            try FileManager.default.createDirectory(
                at: dictionaryDirectory,
                withIntermediateDirectories: true
            )
            try Data("complete".utf8).write(to: markerURL, options: .atomic)
        } catch {
            // A failed seed is intentionally retried on the next launch.
        }
    }
}
