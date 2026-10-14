public enum EmojiDataError: Error, Equatable {
    case missingData(String)
    case invalidCatalog(line: Int)
    case invalidSearch(line: Int)
    case invalidPredictions(line: Int)
}
