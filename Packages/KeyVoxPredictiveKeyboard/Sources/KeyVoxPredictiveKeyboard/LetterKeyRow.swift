import Foundation

/// One row of a letter layout, left to right, as Apple's keyboard lays it out: its character keys,
/// its shift and delete keys, and the empty space between them, each as wide as some number of
/// letter keys.
public struct LetterKeyRow: Sendable, Equatable, Decodable {
    public enum Item: Sendable, Equatable {
        /// A key that types `character`, one letter key wide.
        case character(String)
        case shift(width: Double)
        case delete(width: Double)
        /// Empty space, keyless.
        case padding(width: Double)

        /// How wide the item is, in letter keys.
        public var width: Double {
            switch self {
            case .character:
                return 1
            case let .shift(width), let .delete(width), let .padding(width):
                return width
            }
        }
    }

    public let items: [Item]

    /// How wide the row is, in letter keys.
    public var width: Double {
        items.reduce(0) { $0 + $1.width }
    }

    public init(from decoder: Decoder) throws {
        var container = try decoder.unkeyedContainer()
        var items: [Item] = []
        while container.isAtEnd == false {
            items += try container.decode(StoredItem.self).items
        }
        self.items = items
    }
}

/// One entry of a row in a layout file: a run of character keys, a shift or delete key, or
/// padding, each named by its one key.
private struct StoredItem: Decodable {
    let items: [LetterKeyRow.Item]

    private enum CodingKeys: String, CodingKey {
        case characters, shift, delete, padding
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        guard container.allKeys.count == 1, let key = container.allKeys.first else {
            throw DecodingError.dataCorrupted(.init(
                codingPath: decoder.codingPath,
                debugDescription: "a row entry names exactly one of characters, shift, delete, or padding"
            ))
        }
        switch key {
        case .characters:
            items = try container.decode(String.self, forKey: key).map { .character(String($0)) }
        case .shift:
            items = [.shift(width: try Self.width(in: container, forKey: key))]
        case .delete:
            items = [.delete(width: try Self.width(in: container, forKey: key))]
        case .padding:
            items = [.padding(width: try Self.width(in: container, forKey: key))]
        }
    }

    private static func width(in container: KeyedDecodingContainer<CodingKeys>, forKey key: CodingKeys) throws -> Double {
        let width = try container.decode(Double.self, forKey: key)
        guard width > 0 else {
            throw DecodingError.dataCorruptedError(forKey: key, in: container, debugDescription: "widths are positive")
        }
        return width
    }
}
