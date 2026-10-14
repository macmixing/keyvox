import Testing
@testable import KeyVox_iOS

/// While searching emoji, the keys end in the system emoji keyboard's search row: the page key,
/// space, and done, in place of the page key, the emoji key, space, and return.
struct KeyboardEmojiSearchKeysTests {
    @Test func theLetterPagesSearchRowSwitchesToNumbersAndEndsWithDone() {
        let row = KeyboardSymbolLayout.rows(for: .letters, isEmojiSearch: true).last?.map(\.kind)
        #expect(row == [.numberSymbols, .space, .emojiSearchDone])
    }

    @Test func theSymbolPagesSearchRowSwitchesToLettersAndEndsWithDone() {
        for page in [KeyboardSymbolPage.primary, .alternate] {
            let row = KeyboardSymbolLayout.rows(for: page, isEmojiSearch: true).last?.map(\.kind)
            #expect(row == [.abc, .space, .emojiSearchDone])
        }
    }

    @Test func theOtherRowsStayAsTheyAre() {
        for page in [KeyboardSymbolPage.letters, .primary, .alternate] {
            let searching = KeyboardSymbolLayout.rows(for: page, isEmojiSearch: true)
            let typing = KeyboardSymbolLayout.rows(for: page)
            #expect(Array(searching.dropLast()) == Array(typing.dropLast()))
            #expect(typing.last?.contains { $0.kind == .emoji } == true)
        }
    }
}
