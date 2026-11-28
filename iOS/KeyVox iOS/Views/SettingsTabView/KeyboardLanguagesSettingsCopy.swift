import Foundation

/// The wording for the keyboard's Languages settings screen and the Languages row that opens it.
enum KeyboardLanguagesSettingsCopy {
    static let screenTitle = String(localized: "Languages", comment: "Title of the keyboard Languages settings screen, of the Keyboard settings row that opens it, and of that screen's setting showing the languages the keyboard types in.")
    static let screenDescription = String(localized: "Typing languages and their letter layouts.", comment: "Description under the Languages row in Keyboard settings.")
    static func languageCount(_ count: Int) -> String {
        String(localized: "\(count) Languages", comment: "Value of the keyboard Languages setting when the keyboard types in several languages. %lld is how many; use plural forms.")
    }
    static let changeLanguagesTitle = String(localized: "Change", comment: "Button on the keyboard Languages setting that opens the list of keyboard languages.")
    static let layoutTitle = String(localized: "Layout", comment: "Title of the keyboard setting showing the letter layout, such as QWERTY, of the keyboard's only language.")
    static let layoutsTitle = String(localized: "Layouts", comment: "Title of the keyboard setting that chooses the letter layout, such as QWERTY, of each language when the keyboard has several languages.")
    static let layoutsDescription = String(localized: "Letter layout for each language.", comment: "Description under the keyboard Layouts setting when the keyboard has several languages.")
    static let changeLayoutTitle = String(localized: "Change", comment: "Menu button on the keyboard Layout setting that opens the letter layouts to choose from, by language when the keyboard has several.")
}
