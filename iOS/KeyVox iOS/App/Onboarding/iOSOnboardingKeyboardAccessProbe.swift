import Combine
import Foundation

@MainActor
final class iOSOnboardingKeyboardAccessProbe: ObservableObject {
    typealias TimestampProvider = @MainActor () -> TimeInterval?
    typealias EnabledProvider = @MainActor () -> Bool
    typealias FullAccessProvider = @MainActor () -> Bool

    @Published private(set) var isKeyboardEnabledInSystemSettings: Bool
    @Published private(set) var hasFullAccessConfirmedByKeyboard: Bool
    @Published private(set) var lastConfirmedAccessTimestamp: TimeInterval?

    var hasConfirmedKeyboardAccess: Bool {
        isKeyboardEnabledInSystemSettings && hasFullAccessConfirmedByKeyboard && lastConfirmedAccessTimestamp != nil
    }

    private let timestampProvider: TimestampProvider
    private let enabledProvider: EnabledProvider
    private let fullAccessProvider: FullAccessProvider

    init(
        timestampProvider: TimestampProvider? = nil,
        enabledProvider: EnabledProvider? = nil,
        fullAccessProvider: FullAccessProvider? = nil
    ) {
        let resolvedTimestampProvider = timestampProvider ?? { KeyVoxIPCBridge.keyboardOnboardingAccessTimestamp() }
        let resolvedEnabledProvider = enabledProvider ?? { Self.defaultEnabledProvider() }
        let resolvedFullAccessProvider = fullAccessProvider ?? { KeyVoxIPCBridge.keyboardOnboardingHasFullAccess() }

        self.timestampProvider = resolvedTimestampProvider
        self.enabledProvider = resolvedEnabledProvider
        self.fullAccessProvider = resolvedFullAccessProvider
        isKeyboardEnabledInSystemSettings = resolvedEnabledProvider()
        hasFullAccessConfirmedByKeyboard = resolvedFullAccessProvider()
        lastConfirmedAccessTimestamp = Self.normalizedTimestamp(from: resolvedTimestampProvider())
    }

    func refresh() {
        isKeyboardEnabledInSystemSettings = enabledProvider()
        hasFullAccessConfirmedByKeyboard = fullAccessProvider()
        lastConfirmedAccessTimestamp = Self.normalizedTimestamp(from: timestampProvider())
    }

    private static func normalizedTimestamp(from rawTimestamp: TimeInterval?) -> TimeInterval? {
        guard let rawTimestamp, rawTimestamp.isFinite, rawTimestamp > 0 else {
            return nil
        }

        return rawTimestamp
    }

    private static func defaultEnabledProvider() -> Bool {
        guard let appBundleIdentifier = Bundle.main.bundleIdentifier else {
            return false
        }

        let keyboardIdentifierPrefix = appBundleIdentifier + "."
        let enabledKeyboards = UserDefaults.standard.dictionaryRepresentation()["AppleKeyboards"] as? [String] ?? []
        return enabledKeyboards.contains { $0 == KeyVoxIPCBridge.keyboardBundleIdentifier || $0.hasPrefix(keyboardIdentifierPrefix) }
    }

    static func isKeyboardEnabledInSystemSettings() -> Bool {
        defaultEnabledProvider()
    }
}
