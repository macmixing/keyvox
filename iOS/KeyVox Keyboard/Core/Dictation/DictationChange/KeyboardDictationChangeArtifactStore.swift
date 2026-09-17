import Foundation
import KeyVoxStyleRewrite

final class KeyboardDictationChangeArtifactStore {
    private let defaults: UserDefaults?

    init(defaults: UserDefaults? = UserDefaults(suiteName: KeyVoxIPCBridge.appGroupID)) {
        self.defaults = defaults
    }

    func latestArtifact(matching id: UUID) -> DictationUtteranceArtifact? {
        guard let data = defaults?.data(forKey: KeyVoxIPCBridge.Key.latestDictationArtifactData) else {
            return nil
        }

        guard let artifact = try? JSONDecoder().decode(DictationUtteranceArtifact.self, from: data),
              artifact.id == id else {
            return nil
        }

        return artifact
    }
}
