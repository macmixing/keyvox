import XCTest

/// Screen positions of a keyboard's letter keys and space bar, used to turn planned
/// key-pitch offsets into screen points on that keyboard's own key sizes.
struct KeyboardKeyMap {
    private static let letters = Array("qwertyuiopasdfghjklzxcvbnm")

    private let centers: [Character: CGPoint]
    private let pitch: CGSize
    let spaceCenter: CGPoint

    /// The system keyboard, whose keys are exposed as keyboard keys.
    init(systemKeyboard keyboard: XCUIElement) throws {
        try self.init(spaceLabel: "space") { label in keyboard.keys[label] }
    }

    /// A third-party keyboard, whose keys are found by their accessibility labels.
    init(customKeyboardIn app: XCUIApplication) throws {
        try self.init(spaceLabel: "Space") { label in
            app.descendants(matching: .any)
                .matching(NSPredicate(format: "label == %@", label))
                .firstMatch
        }
    }

    private init(spaceLabel: String, key: (String) -> XCUIElement) throws {
        var centers: [Character: CGPoint] = [:]
        for letter in Self.letters {
            // Shifted keyboards label their letter keys with capitals.
            guard let element = [String(letter), String(letter).uppercased()].lazy.map(key).first(where: \.exists) else {
                throw KeyMapError.missingKey(String(letter))
            }
            centers[letter] = CGPoint(x: element.frame.midX, y: element.frame.midY)
        }
        let space = key(spaceLabel)
        guard space.exists else { throw KeyMapError.missingKey(spaceLabel) }
        spaceCenter = CGPoint(x: space.frame.midX, y: space.frame.midY)
        self.centers = centers
        pitch = CGSize(
            width: centers["w"]!.x - centers["q"]!.x,
            height: centers["a"]!.y - centers["q"]!.y
        )
    }

    func point(for letter: Character, offset: [Double]) -> CGPoint? {
        guard let center = centers[letter] else { return nil }
        return CGPoint(
            x: center.x + offset[0] * pitch.width,
            y: center.y + offset[1] * pitch.height
        )
    }

    enum KeyMapError: Error {
        case missingKey(String)
    }
}
