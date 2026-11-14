import CoreGraphics
import Testing
import UIKit
@testable import KeyVox_iOS

struct KeyboardFieldKeysTests {
    @Test func keyboardTypesPickTheirBottomRowAndNumberPad() {
        let expectations: [(UIKeyboardType, KeyboardFieldKeys.BottomRow, KeyboardFieldKeys.NumberPad?)] = [
            (.default, .standard, nil),
            (.URL, .webAddress, nil),
            (.webSearch, .webSearch, nil),
            (.emailAddress, .email, nil),
            (.twitter, .socialPost, nil),
            (.numbersAndPunctuation, .standard, nil),
            (.numberPad, .standard, .digits),
            (.asciiCapableNumberPad, .standard, .digits),
            (.decimalPad, .standard, .decimal),
        ]
        for (keyboardType, bottomRow, numberPad) in expectations {
            let keys = KeyboardFieldKeys(keyboardType: keyboardType, returnKeyType: .default)
            #expect(keys.bottomRow == bottomRow)
            #expect(keys.numberPad == numberPad)
        }
    }

    @Test func returnKeyTypesShareTheSystemKeyboardsLooks() {
        func style(_ type: UIReturnKeyType) -> KeyboardReturnKeyStyle {
            KeyboardReturnKeyStyle(returnKeyType: type)
        }
        #expect(style(.default).systemImageName == nil)
        #expect(style(.default).isAction == false)
        for type in [UIReturnKeyType.next, .continue] {
            #expect(style(type).isAction == false)
            #expect(style(type).systemImageName == style(.next).systemImageName)
        }
        for type in [UIReturnKeyType.go, .join, .route] {
            #expect(style(type).isAction)
            #expect(style(type).systemImageName == style(.go).systemImageName)
        }
        for type in [UIReturnKeyType.search, .google, .yahoo] {
            #expect(style(type).isAction)
            #expect(style(type).systemImageName == style(.search).systemImageName)
        }
        let actionSymbols = [UIReturnKeyType.go, .search, .send, .done, .emergencyCall].map { style($0).systemImageName }
        #expect(actionSymbols.allSatisfy { $0 != nil })
        #expect(Set(actionSymbols).count == actionSymbols.count)
    }

    @Test func onlyAFullLetterPageShowsTheFieldsRowExceptSearchOnEveryPage() {
        let webAddress = KeyboardFieldKeys(keyboardType: .URL, returnKeyType: .default)
        let webSearch = KeyboardFieldKeys(keyboardType: .webSearch, returnKeyType: .default)

        #expect(webAddress.bottomRow(on: .letters, keysMode: .full, isEmojiSearch: false) == .webAddress)
        #expect(webAddress.bottomRow(on: .primary, keysMode: .full, isEmojiSearch: false) == .standard)
        #expect(webAddress.bottomRow(on: .letters, keysMode: .full, isEmojiSearch: true) == .standard)
        for page in [KeyboardSymbolPage.letters, .primary, .alternate] {
            #expect(webSearch.bottomRow(on: page, keysMode: .full, isEmojiSearch: false) == .webSearch)
        }
        #expect(webSearch.bottomRow(on: .primary, keysMode: .compact, isEmojiSearch: false) == .standard)
    }

    @Test func webAddressRowTypesTheCommonEndingInsteadOfSpaces() {
        let bottomRow = lettersBottomRow(for: .URL)

        #expect(bottomRow.contains { $0.kind == .space } == false)
        #expect(bottomRow.contains { $0.kind == .character(KeyboardFieldKeys.commonWebEnding) })
        #expect(bottomRow.last?.kind == .returnKey)
    }

    @Test func emailAndSearchDotsOfferTheWebEndings() {
        for keyboardType in [UIKeyboardType.emailAddress, .webSearch] {
            let dot = lettersBottomRow(for: keyboardType).first { $0.kind == .character(".") }
            #expect(dot?.heldOfferKey == KeyboardFieldKeys.commonWebEnding)
        }
        let emailRow = lettersBottomRow(for: .emailAddress)
        #expect(emailRow.contains { $0.kind == .character("@") })
        #expect(emailRow.contains { $0.kind == .space })
    }

    @Test func socialPostRowHasNoReturnKey() {
        let bottomRow = lettersBottomRow(for: .twitter)

        #expect(bottomRow.contains { $0.kind == .returnKey } == false)
        #expect(Array(bottomRow.suffix(2)).map(\.kind) == [.character("@"), .character("#")])
    }

    @Test func everyPagesReturnKeyTakesTheFieldsLook() {
        let fieldKeys = KeyboardFieldKeys(keyboardType: .default, returnKeyType: .send)
        for page in [KeyboardSymbolPage.letters, .primary, .alternate] {
            let returnKeys = KeyboardSymbolLayout.rows(for: page, fieldKeys: fieldKeys)
                .flatMap { $0 }
                .filter { $0.kind == .returnKey }
            #expect(returnKeys.count == 1)
            #expect(returnKeys.allSatisfy { $0.returnKeyStyle == fieldKeys.returnKey && $0.isActionKey })
        }
    }

    @Test func fieldRowsKeepEmojiAndGlobeVariations() {
        let fieldKeys = KeyboardFieldKeys(keyboardType: .emailAddress, returnKeyType: .default)
        let withoutEmoji = KeyboardSymbolLayout.rows(for: .letters, showsEmojiKey: false, fieldKeys: fieldKeys).last!
        let withGlobe = KeyboardSymbolLayout.rows(for: .letters, showsNextKeyboardKey: true, fieldKeys: fieldKeys).last!

        #expect(withoutEmoji.contains { $0.kind == .emoji } == false)
        #expect(withoutEmoji.contains { $0.kind == .character("@") })
        #expect(withGlobe.contains { $0.kind == .nextKeyboard })
        #expect(withGlobe.contains { $0.kind == .character("@") })
    }

    @Test func everyBottomRowFillsTheRowWithItsKeys() {
        let rowWidth: CGFloat = 394
        let spacing = KeyboardStyle.keySpacing
        let bottomRows: [KeyboardFieldKeys.BottomRow] = [.standard, .webAddress, .webSearch, .email, .socialPost]
        for bottomRow in bottomRows {
            for leadingCount in 1...3 {
                for isLandscape in [false, true] {
                    let keyCount = leadingCount + trailingKeys(of: bottomRow)
                    let widths = KeyboardLayoutGeometry.BottomRowLayout.widths(
                        rowWidth: rowWidth,
                        keyCount: keyCount,
                        bottomRow: bottomRow,
                        isLandscape: isLandscape
                    )
                    let total = (widths ?? []).reduce(0, +) + spacing * CGFloat(keyCount - 1)
                    #expect(widths?.count == keyCount)
                    #expect(abs(total - rowWidth) < 0.001)
                }
            }
        }
    }

    @Test func fieldKeysSplitTheirPlacesAsTheSystemKeyboardDoes() throws {
        func widths(_ bottomRow: KeyboardFieldKeys.BottomRow, keyCount: Int) throws -> [CGFloat] {
            try #require(KeyboardLayoutGeometry.BottomRowLayout.widths(
                rowWidth: 394,
                keyCount: keyCount,
                bottomRow: bottomRow,
                isLandscape: false
            ))
        }
        let standard = try widths(.standard, keyCount: 4)
        let pageKeyWidth = standard[0]
        let returnWidth = standard[3]

        let webAddress = try widths(.webAddress, keyCount: 6)
        #expect(abs(webAddress[2] - webAddress[3]) < 0.001 && abs(webAddress[3] - webAddress[4]) < 0.001)
        #expect(abs(webAddress[5] - returnWidth) < 0.001)

        let email = try widths(.email, keyCount: 6)
        #expect(abs(email[3] - pageKeyWidth) < 0.001 && abs(email[4] - pageKeyWidth) < 0.001)

        let webSearch = try widths(.webSearch, keyCount: 5)
        #expect(abs(webSearch[4] - webSearch[3] * 2) < 0.001)

        let socialPost = try widths(.socialPost, keyCount: 5)
        #expect(abs(socialPost[2] - standard[2]) < 0.001)
        #expect(abs(socialPost[3] - pageKeyWidth) < 0.001 && abs(socialPost[4] - pageKeyWidth) < 0.001)
    }

    @Test func numberPadRowsHoldDigitsOverZeroAndDelete() {
        let digits = KeyboardSymbolLayout.rows(for: .numberPad, fieldKeys: KeyboardFieldKeys(keyboardType: .numberPad, returnKeyType: .default))
        let digitKeys = digits.dropLast().flatMap { $0 }

        #expect(digits.count == 4)
        #expect(digits.dropLast().allSatisfy { $0.count == 3 })
        #expect(digitKeys.allSatisfy { $0.isNumberPadKey && $0.heldOfferKey == nil && $0.allowsPopup == false })
        #expect(digits.last?.map(\.kind) == [.character("0"), .delete])
    }

    @Test func numberPadBottomRowMakesRoomForTheSeparatorAndGlobe() {
        let separator = ","
        let decimal = KeyboardNumberPadLayout.rows(for: .decimal, showsNextKeyboardKey: false, decimalSeparator: separator)
        let decimalWithGlobe = KeyboardNumberPadLayout.rows(for: .decimal, showsNextKeyboardKey: true, decimalSeparator: separator)
        let digitsWithGlobe = KeyboardNumberPadLayout.rows(for: .digits, showsNextKeyboardKey: true)

        #expect(decimal.last?.map(\.kind) == [.character(separator), .character("0"), .delete])
        #expect(decimalWithGlobe.last?.map(\.kind) == [.nextKeyboard, .character(separator), .character("0"), .delete])
        #expect(digitsWithGlobe.last?.map(\.kind) == [.nextKeyboard, .character("0"), .delete])
    }

    @Test func numbersOnlyFieldsOpenTheFullNumberPad() {
        let layout = KeyboardOpeningLayout.resolve(
            prefersNumberPage: true,
            opensNumberPad: true,
            isCompactKeysEnabled: true,
            isCompactKeysActive: true
        )

        #expect(layout == KeyboardOpeningLayout(symbolPage: .numberPad, keysMode: .full))
    }

    private func lettersBottomRow(for keyboardType: UIKeyboardType) -> [KeyboardKeyModel] {
        let fieldKeys = KeyboardFieldKeys(keyboardType: keyboardType, returnKeyType: .default)
        return KeyboardSymbolLayout.rows(for: .letters, fieldKeys: fieldKeys).last ?? []
    }

    private func trailingKeys(of bottomRow: KeyboardFieldKeys.BottomRow) -> Int {
        let standardTail = [KeyboardSymbolLayout.key(.space), KeyboardSymbolLayout.key(.returnKey)]
        return KeyboardFieldBottomRowKeys.trailingKeys(for: bottomRow, replacing: standardTail).count
    }
}
