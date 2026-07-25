import Foundation

enum KeyboardAlternateCharacterLayout {
    static func characters(for value: String) -> [String] {
        guard value.count == 1 else { return [] }
        let isUppercase = value == value.uppercased() && value != value.lowercased()
        let alternates = lowercaseAlternates[value.lowercased()] ?? []
        return isUppercase
            ? alternates.map { $0 == "ß" ? "ẞ" : $0.uppercased() }
            : alternates
    }

    private static let lowercaseAlternates: [String: [String]] = [
        "a": ["à", "á", "â", "ä", "æ", "ã", "å", "ā"],
        "c": ["ç", "ć", "č"],
        "e": ["è", "é", "ê", "ë", "ē", "ė", "ę"],
        "i": ["î", "ï", "í", "ī", "į", "ì"],
        "l": ["ł"],
        "n": ["ñ", "ń"],
        "o": ["ô", "ö", "ò", "ó", "œ", "ø", "ō", "õ"],
        "s": ["ß", "ś", "š"],
        "u": ["û", "ü", "ù", "ú", "ū"],
        "y": ["ÿ"],
        "z": ["ž", "ź", "ż"],
        "-": ["–", "—", "•"],
        "/": ["\\"],
        "$": ["€", "£", "¥", "₩", "₽", "¢"],
        "&": ["§"],
        "\"": ["“", "”", "„", "«", "»"],
        "‘": ["'", "’", "`"],
        "’": ["'", "‘", "`"],
        ".": ["…"],
        "?": ["¿"],
        "!": ["¡"],
    ]
}
