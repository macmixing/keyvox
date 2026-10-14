import CoreGraphics
import KeyVoxEmoji
import Testing
@testable import KeyVox_iOS

/// Tapping a category goes where the system emoji keyboard went when watched.
struct KeyboardEmojiCategoryMemoryTests {
    @Test func aCategoryNeverShownOpensAtItsStart() {
        let memory = KeyboardEmojiCategoryMemory()
        #expect(memory.offset(forTapping: .foodDrink, sectionStart: 500, showing: .animalsNature) == 500)
    }

    @Test func aCategoryShownBeforeOpensWhereTheGridWasInIt() {
        var memory = KeyboardEmojiCategoryMemory()
        memory.gridScrolled(to: 700, showing: .foodDrink)
        memory.gridScrolled(to: 200, showing: .animalsNature)
        #expect(memory.offset(forTapping: .foodDrink, sectionStart: 500, showing: .animalsNature) == 700)
    }

    @Test func theCategoryShowingOpensAtItsStart() {
        var memory = KeyboardEmojiCategoryMemory()
        memory.gridScrolled(to: 700, showing: .foodDrink)
        #expect(memory.offset(forTapping: .foodDrink, sectionStart: 500, showing: .foodDrink) == 500)
    }
}
