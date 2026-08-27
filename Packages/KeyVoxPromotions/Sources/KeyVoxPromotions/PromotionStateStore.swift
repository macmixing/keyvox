import Foundation

public final class PromotionStateStore: @unchecked Sendable {
    private enum Key {
        static let cachedManifestData = "CachedManifestData"
        static let selectionState = "SelectionState"
    }

    private let defaults: UserDefaults
    private let namespace: String

    public init(defaults: UserDefaults, namespace: String) {
        self.defaults = defaults
        self.namespace = namespace
    }

    func cachedManifestData() -> Data? {
        defaults.data(forKey: key(Key.cachedManifestData))
    }

    func setCachedManifestData(_ data: Data) {
        defaults.set(data, forKey: key(Key.cachedManifestData))
    }

    func selectionState() -> PromotionSelectionState? {
        guard let data = defaults.data(forKey: key(Key.selectionState)) else { return nil }
        return try? JSONDecoder().decode(PromotionSelectionState.self, from: data)
    }

    func setSelectionState(_ state: PromotionSelectionState?) {
        guard let state else {
            defaults.removeObject(forKey: key(Key.selectionState))
            return
        }
        guard let data = try? JSONEncoder().encode(state) else { return }
        defaults.set(data, forKey: key(Key.selectionState))
    }

    private func key(_ suffix: String) -> String {
        "\(namespace).\(suffix)"
    }
}
