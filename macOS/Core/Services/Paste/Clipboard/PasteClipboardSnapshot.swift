import Cocoa

protocol PasteClipboardAdapting {
    func captureSnapshot() -> PasteClipboardSnapshot.Snapshot
    func setString(_ text: String)
    func restore(_ snapshot: PasteClipboardSnapshot.Snapshot)
}

final class SystemPasteboardAdapter: PasteClipboardAdapting {
    private let pasteboard: NSPasteboard

    init(pasteboard: NSPasteboard = .general) {
        self.pasteboard = pasteboard
    }

    func captureSnapshot() -> PasteClipboardSnapshot.Snapshot {
        PasteClipboardSnapshot.captureCurrentPasteboardItems(pasteboard)
    }

    func setString(_ text: String) {
        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)
    }

    func restore(_ snapshot: PasteClipboardSnapshot.Snapshot) {
        PasteClipboardSnapshot.restore(snapshot, to: pasteboard)
    }
}

enum PasteClipboardSnapshot {
    typealias Snapshot = [[NSPasteboard.PasteboardType: Data]]

    static func captureCurrentPasteboardItems(_ pasteboard: NSPasteboard = .general) -> Snapshot {
        let savedItems = pasteboard.pasteboardItems ?? []
        return savedItems.map { item in
            var dict: [NSPasteboard.PasteboardType: Data] = [:]
            for type in item.types {
                if let data = item.data(forType: type) {
                    dict[type] = data
                }
            }
            return dict
        }
    }

    static func restore(_ snapshot: Snapshot, to pasteboard: NSPasteboard = .general) {
        pasteboard.clearContents()

        // Restore original clipboard items (files, images, rich text, etc.).
        let itemsToWrite: [NSPasteboardItem] = snapshot.map { itemDict in
            let newItem = NSPasteboardItem()
            for (type, data) in itemDict {
                newItem.setData(data, forType: type)
            }
            return newItem
        }

        if !itemsToWrite.isEmpty {
            let didWrite = pasteboard.writeObjects(itemsToWrite)

            // Rare fallback path when writeObjects fails.
            if !didWrite {
                pasteboard.clearContents()
                if let first = snapshot.first {
                    for (type, data) in first {
                        pasteboard.setData(data, forType: type)
                    }
                }
            }
        }

        #if DEBUG
        print("Clipboard state restored (items: \(itemsToWrite.count)).")
        #endif
    }
}
