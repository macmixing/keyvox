import Foundation
import QuartzCore

/// Records every change to the text, with the seconds since the text was filled, to
/// `Documents/deletion-timeline.json`, so holding a keyboard's delete key can be read back
/// as what it deleted and when.
final class DeletionTimeline {
    struct Entry: Codable {
        let time: Double
        let text: String
    }

    static let shared = DeletionTimeline()

    private var start: CFTimeInterval = 0
    private var entries: [Entry] = []
    private let url = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        .appendingPathComponent("deletion-timeline.json")

    /// Starts a new timeline at `text`.
    func reset(to text: String) {
        start = CACurrentMediaTime()
        entries = [Entry(time: 0, text: text)]
        write()
    }

    func record(_ text: String) {
        guard entries.isEmpty == false, text != entries.last?.text else { return }
        entries.append(Entry(time: CACurrentMediaTime() - start, text: text))
        write()
    }

    private func write() {
        try? JSONEncoder().encode(entries).write(to: url, options: .atomic)
    }
}
