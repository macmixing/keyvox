/// The layout of a swipe lexicon file (`swipe_lexicon.kvsl`), shared by its writer and reader.
///
/// A file is the 4-byte magic, then little-endian `UInt32`s: the version, the byte count of the
/// model's key letters as UTF-8, those bytes padded with zeros to a multiple of four, whether
/// key paths keep doubled letters (0 or 1), and the node, form, spelling, and spelling-byte
/// counts. Then come the tables, `UInt32` ones first so each starts four-byte aligned:
///
/// - `childStart` [nodes + 1] and `childNode` [nodes - 1]: each node's children, by key.
/// - `formStart` [nodes + 1]: the forms whose key path ends at each node.
/// - `formSpellingStart` [forms + 1]: each form's spellings, likeliest first.
/// - `spellingOffset` [spellings + 1]: where each spelling's UTF-8 bytes start.
/// - `nodeKey` [nodes] (255 for the root), `nodeDepth` [nodes], `formFrequency` [forms],
///   `formPathLength` [forms], `spellingFrequency` [spellings], then the spelling bytes.
///
/// Node 0 is the empty key path; node numbers follow the order the trie was built in, every
/// typeable form in Unicode scalar order.
enum SwipeLexiconFormat {
    static let magic: [UInt8] = Array("KVSL".utf8)
    static let version: UInt32 = 1
    static let rootKey: UInt8 = 255
    static let fileName = "swipe_lexicon.kvsl"
}
