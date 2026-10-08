import CoreHaptics

/// The tap felt on a letter or character key: one tiny, crisp tick made to feel like the system
/// keyboard's text input tap. A transient's sharpness picks which recorded tap the device plays,
/// and full sharpness picks its lightest; the intensity sets how strongly that tap plays.
enum KeyboardTextInputHapticPattern {
    static let intensity: Float = 0.57
    static let sharpness: Float = 1

    static func make() throws -> CHHapticPattern {
        let tap = CHHapticEvent(
            eventType: .hapticTransient,
            parameters: [
                CHHapticEventParameter(parameterID: .hapticIntensity, value: intensity),
                CHHapticEventParameter(parameterID: .hapticSharpness, value: sharpness),
            ],
            relativeTime: 0
        )
        return try CHHapticPattern(events: [tap], parameters: [])
    }
}
