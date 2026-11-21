import Foundation

/// Keeps the transcript of a dictation that was cut off by its keyboard going away, so the next
/// keyboard to appear can offer it. The dictation lives in the keyboard's own defaults, since the
/// keyboard that finished it and the one that offers it can be different view controllers.
final class KeyboardRescuedDictationStore {
    /// A rescued transcript and the published dictation it came from, which lets the keyboard's
    /// dictation controls act on it once inserted.
    struct Dictation: Equatable {
        let text: String
        let artifactID: UUID?
        let styleIdentifier: String?
    }

    /// Posted on the main queue, by the store that made it, whenever the kept dictation changes.
    static let didChangeNotification = Notification.Name("KeyboardRescuedDictationStore.didChange")

    private static let textKey = "KeyboardRescuedDictationStore.text"
    private static let artifactIDKey = "KeyboardRescuedDictationStore.artifactID"
    private static let styleIdentifierKey = "KeyboardRescuedDictationStore.styleIdentifier"

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    /// The kept dictation, if there is one.
    var dictation: Dictation? {
        guard let text = defaults.string(forKey: Self.textKey) else { return nil }
        return Dictation(
            text: text,
            artifactID: defaults.string(forKey: Self.artifactIDKey).flatMap(UUID.init(uuidString:)),
            styleIdentifier: defaults.string(forKey: Self.styleIdentifierKey)
        )
    }

    func save(_ dictation: Dictation) {
        defaults.set(dictation.text, forKey: Self.textKey)
        set(dictation.artifactID?.uuidString, forKey: Self.artifactIDKey)
        set(dictation.styleIdentifier, forKey: Self.styleIdentifierKey)
        postChange()
    }

    func clear() {
        guard defaults.string(forKey: Self.textKey) != nil else { return }
        defaults.removeObject(forKey: Self.textKey)
        defaults.removeObject(forKey: Self.artifactIDKey)
        defaults.removeObject(forKey: Self.styleIdentifierKey)
        postChange()
    }

    private func set(_ value: String?, forKey key: String) {
        if let value {
            defaults.set(value, forKey: key)
        } else {
            defaults.removeObject(forKey: key)
        }
    }

    private func postChange() {
        let post = { NotificationCenter.default.post(name: Self.didChangeNotification, object: self) }
        if Thread.isMainThread {
            post()
        } else {
            DispatchQueue.main.async(execute: post)
        }
    }
}
