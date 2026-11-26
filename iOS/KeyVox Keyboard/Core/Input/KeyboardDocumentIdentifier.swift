import UIKit

/// Reads the host's identifier for the focused field's document. UIKit declares it as always
/// present, but a host can hand over none, and reading a missing one as a Swift `UUID` stops the
/// keyboard; read through Objective-C, a missing identifier is nil.
enum KeyboardDocumentIdentifier {
    static func read(from proxy: NSObjectProtocol) -> UUID? {
        let getter = #selector(getter: UITextDocumentProxy.documentIdentifier)
        guard proxy.responds(to: getter) else { return nil }
        return proxy.perform(getter)?.takeUnretainedValue() as? UUID
    }
}
