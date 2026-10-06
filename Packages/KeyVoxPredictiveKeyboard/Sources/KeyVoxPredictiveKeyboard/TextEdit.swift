/// A change the host applies at the cursor: delete characters before it, then insert text.
public struct TextEdit: Sendable, Equatable {
    /// Characters (grapheme clusters) to delete before the cursor.
    public let deleteCount: Int
    public let insertText: String

    public init(deleteCount: Int, insertText: String) {
        self.deleteCount = deleteCount
        self.insertText = insertText
    }
}
