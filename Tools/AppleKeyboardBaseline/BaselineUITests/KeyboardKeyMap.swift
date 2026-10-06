import XCTest

/// Screen positions of the system keyboard's letter keys and space bar, used to turn
/// planned key-pitch offsets into screen points on Apple's own key sizes.
struct KeyboardKeyMap {
    private static let letters = Array("qwertyuiopasdfghjklzxcvbnm")

    private let centers: [Character: CGPoint]
    private let pitch: CGSize
    let spaceCenter: CGPoint

    init(keyboard: XCUIElement) throws {
        var centers: [Character: CGPoint] = [:]
        for letter in Self.letters {
            let key = keyboard.keys[String(letter)]
            guard key.exists else {
                throw KeyMapError.missingKey(String(letter))
            }
            let frame = key.frame
            centers[letter] = CGPoint(x: frame.midX, y: frame.midY)
        }
        let space = keyboard.keys["space"]
        guard space.exists else { throw KeyMapError.missingKey("space") }
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
