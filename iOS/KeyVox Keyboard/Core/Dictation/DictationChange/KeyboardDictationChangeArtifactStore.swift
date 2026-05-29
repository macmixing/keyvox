import Foundation
import KeyVoxStyleRewrite

final class KeyboardDictationChangeArtifactStore {
    private let defaults: UserDefaults?

    init(defaults: UserDefaults? = UserDefaults(suiteName: KeyVoxIPCBridge.appGroupID)) {
        self.defaults = defaults
    }

    func latestArtifact() -> DictationUtteranceArtifact? {
        guard let data = defaults?.data(forKey: KeyVoxIPCBridge.Key.latestDictationArtifactData) else {
            return nil
        }

        return try? JSONDecoder().decode(DictationUtteranceArtifact.self, from: data)
    }
}
