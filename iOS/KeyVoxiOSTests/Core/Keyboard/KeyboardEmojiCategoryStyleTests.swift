import KeyVoxEmoji
import Testing
import UIKit
@testable import KeyVox_iOS

/// Every picture the emoji keys and bar use is an SF Symbol the system has.
struct KeyboardEmojiCategoryStyleTests {
    @Test func everyCategorysSymbolExists() {
        for category in EmojiKeyboardCategory.allCases {
            #expect(UIImage(systemName: category.symbolName) != nil, "\(category)")
        }
    }

    @Test func theEmojiKeysSymbolExists() throws {
        let name = try #require(KeyboardKeyModel(kind: .emoji, widthUnits: 1).systemImageName)
        #expect(UIImage(systemName: name) != nil)
    }
}
