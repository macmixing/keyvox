/// What the emoji key opened: nothing, the emoji page in the key grid's place, or the emoji search
/// over the letter keys. Both show the search field in the toolbar's place.
enum KeyboardEmojiPanel: Equatable {
    case closed
    case browsing
    case searching
}
