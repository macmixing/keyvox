import Foundation
import KeyVoxStyleRewrite

final class StyleRewriteLatestArtifactStore {
    static var latestArtifactDataKeyForTests: String {
        KeyVoxIPCBridge.Key.latestDictationArtifactData
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

        defaults?.set(data, forKey: KeyVoxIPCBridge.Key.latestDictationArtifactData)
    }

    func clear() {
        defaults?.removeObject(forKey: KeyVoxIPCBridge.Key.latestDictationArtifactData)
    }

    func data() -> Data? {
        defaults?.data(forKey: KeyVoxIPCBridge.Key.latestDictationArtifactData)
    }

    func artifact() -> DictationUtteranceArtifact? {
        guard let data = data() else { return nil }

        do {
            return try JSONDecoder().decode(DictationUtteranceArtifact.self, from: data)
        } catch {
            log("Failed to decode latest artifact key=\(KeyVoxIPCBridge.Key.latestDictationArtifactData) error=\(error)")
            return nil
        }
    }

    private func log(_ message: @autoclosure () -> String) {
        #if DEBUG
        NSLog("[StyleRewriteLatestArtifactStore] %@", message())
        #endif
    }
}
