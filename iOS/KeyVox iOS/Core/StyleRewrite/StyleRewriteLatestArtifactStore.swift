import Foundation
import KeyVoxStyleRewrite

final class StyleRewriteLatestArtifactStore {
    private enum Key {
        static let latestArtifactData = "KeyVox.StyleRewrite.LatestDictationArtifactData"
    }

    static var latestArtifactDataKeyForTests: String {
        Key.latestArtifactData
    }

    private let defaults: UserDefaults?

    init(defaults: UserDefaults?) {
        self.defaults = defaults
    }

    func save(_ artifact: DictationUtteranceArtifact) {
        let data: Data
        do {
            data = try JSONEncoder().encode(artifact)
        } catch {
            log(
                "Failed to encode latest artifact id=\(artifact.id) style=\(artifact.selectedStyleIdentifier ?? "none") error=\(error)"
            )
            return
        }

        defaults?.set(data, forKey: Key.latestArtifactData)
    }

    func clear() {
        defaults?.removeObject(forKey: Key.latestArtifactData)
    }

    func data() -> Data? {
        defaults?.data(forKey: Key.latestArtifactData)
    }

    func artifact() -> DictationUtteranceArtifact? {
        guard let data = data() else { return nil }

        do {
            return try JSONDecoder().decode(DictationUtteranceArtifact.self, from: data)
        } catch {
            log("Failed to decode latest artifact key=\(Key.latestArtifactData) error=\(error)")
            return nil
        }
    }

    private func log(_ message: @autoclosure () -> String) {
        #if DEBUG
        NSLog("[StyleRewriteLatestArtifactStore] %@", message())
        #endif
    }
}
