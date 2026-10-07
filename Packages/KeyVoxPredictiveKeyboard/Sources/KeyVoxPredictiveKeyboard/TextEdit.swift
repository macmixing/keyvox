/// A change the host applies at the cursor: delete characters around it, then insert text.
public struct TextEdit: Sendable, Equatable {
    /// Characters (grapheme clusters) to delete before the cursor.
    public let deleteCount: Int
    public let insertText: String
    /// Characters to delete after the cursor as well, such as the rest of the word it is in.
    public let deleteAfterCount: Int

    public init(deleteCount: Int, insertText: String, deleteAfterCount: Int = 0) {
        self.deleteCount = deleteCount
        self.insertText = insertText
        self.deleteAfterCount = deleteAfterCount
    }
}
