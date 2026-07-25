import Foundation

enum KeyboardTypingDiagnostics {
#if DEBUG
    private static let recorder = Recorder()

    static func nextIdentifier() -> Int {
        recorder.nextIdentifier()
    }

    static func log(_ event: String, fields: [String: Any] = [:]) {
        recorder.log(event, fields: fields)
    }

    static func withTouchIdentifier<Result>(
        _ identifier: Int,
        operation: () throws -> Result
    ) rethrows -> Result {
        try recorder.withTouchIdentifier(identifier, operation: operation)
    }
#else
    static func nextIdentifier() -> Int { 0 }

    static func log(_: String, fields _: [String: Any] = [:]) {}

    static func withTouchIdentifier<Result>(
        _: Int,
        operation: () throws -> Result
    ) rethrows -> Result {
        try operation()
    }
#endif
}

#if DEBUG
private final class Recorder: @unchecked Sendable {
    private static let touchIdentifierKey = "KeyVoxTypingDiagnosticTouchIdentifier"
    private let lock = NSLock()
    private let outputQueue = DispatchQueue(
        label: "com.domestudios.keyvox.typing-diagnostics",
        qos: .utility
    )
    private var nextEventIdentifier = 1
    private var nextLogSequence = 1

    func nextIdentifier() -> Int {
        lock.withLock {
            defer { nextEventIdentifier += 1 }
            return nextEventIdentifier
        }
    }

    func log(_ event: String, fields: [String: Any]) {
        var payload = fields
        if payload["touch_id"] == nil,
           let touchIdentifier = Thread.current.threadDictionary[Self.touchIdentifierKey] as? Int {
            payload["touch_id"] = touchIdentifier
        }
        payload["event"] = event
        payload["uptime_ms"] = Int((ProcessInfo.processInfo.systemUptime * 1_000).rounded())
        payload["main_thread"] = Thread.isMainThread
        lock.withLock {
            payload["sequence"] = nextLogSequence
            nextLogSequence += 1
            let pendingLog = PendingLog(payload: payload)
            outputQueue.async {
                pendingLog.writeToConsole()
            }
        }
    }

    func withTouchIdentifier<Result>(
        _ identifier: Int,
        operation: () throws -> Result
    ) rethrows -> Result {
        let dictionary = Thread.current.threadDictionary
        let previousIdentifier = dictionary[Self.touchIdentifierKey]
        dictionary[Self.touchIdentifierKey] = identifier
        defer {
            if let previousIdentifier {
                dictionary[Self.touchIdentifierKey] = previousIdentifier
            } else {
                dictionary.removeObject(forKey: Self.touchIdentifierKey)
            }
        }
        return try operation()
    }
}

private final class PendingLog: @unchecked Sendable {
    private let payload: [String: Any]

    init(payload: [String: Any]) {
        self.payload = payload
    }

    func writeToConsole() {
        guard JSONSerialization.isValidJSONObject(payload),
              let data = try? JSONSerialization.data(withJSONObject: payload, options: [.sortedKeys]),
              let encoded = String(data: data, encoding: .utf8) else {
            print("[KeyVoxTyping] event=encoding_failure")
            return
        }
        print("[KeyVoxTyping] \(encoded)")
    }
}
#endif
