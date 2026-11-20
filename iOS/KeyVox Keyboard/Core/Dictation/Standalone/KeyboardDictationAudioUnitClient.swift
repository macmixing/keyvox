import AVFoundation
import AudioToolbox

/// Hosts the dictation Audio Unit extension out of process and exchanges messages with it.
/// Every exchange waits for the extension's answer, so the client works on its own queue and
/// reports back on the main queue.
final class KeyboardDictationAudioUnitClient: @unchecked Sendable {
    enum Outcome: Sendable {
        case transcript(String)
        case noSpeech
        case failed
    }

    typealias LiveMeter = (level: Float, signalState: KeyVoxIPCLiveMeterSignalState)

    private typealias Key = DictationAudioUnitContract.Key

    private static let componentDiscoveryTimeout: TimeInterval = 2
    private static let componentDiscoveryPollInterval: TimeInterval = 0.02
    private static let instantiationTimeout: TimeInterval = 10
    private static let outcomePollInterval: TimeInterval = 0.05

    private let queue = DispatchQueue(label: "com.cueit.keyvox.keyboard.dictation-audio-unit")
    // Both are used only on `queue`.
    private var audioUnit: AVAudioUnit?
    private var messageChannel: (any AUMessageChannel)?

    /// Starts the extension if it is not running, without beginning a dictation.
    func prepare() {
        queue.async { [self] in
            _ = connect()
        }
    }

    /// Starts the extension if it is not running and begins a dictation in it. Reports whether
    /// the extension took the dictation.
    func begin(styleIdentifier: String, completion: @escaping @MainActor (Bool) -> Void) {
        queue.async { [self] in
            let accepted = connect()
                && send(.begin, [Key.styleIdentifier: styleIdentifier])?[Key.accepted] as? Bool == true
            DispatchQueue.main.async {
                completion(accepted)
            }
        }
    }

    /// Adds audio to the dictation. Reports the live meter for it, or nil when the extension
    /// did not take it.
    func append(audio: Data, sampleRate: Double, completion: @escaping @MainActor (LiveMeter?) -> Void) {
        queue.async { [self] in
            let meter = liveMeter(from: send(.appendAudio, [Key.audio: audio, Key.sampleRate: sampleRate]))
            DispatchQueue.main.async {
                completion(meter)
            }
        }
    }

    /// Ends the dictation's audio and reports what the extension made of it.
    func finish(completion: @escaping @MainActor (Outcome) -> Void) {
        queue.async { [self] in
            let outcome = send(.finish)?[Key.accepted] as? Bool == true ? awaitOutcome() : .failed
            DispatchQueue.main.async {
                completion(outcome)
            }
        }
    }

    /// Abandons the dictation in the extension.
    func cancel() {
        queue.async { [self] in
            _ = send(.cancel)
        }
    }

    /// Abandons the dictation, has the extension free its models, and lets go of it.
    func disconnect() {
        queue.async { [self] in
            _ = send(.releaseModels)
            messageChannel = nil
            audioUnit = nil
        }
    }

    private func connect() -> Bool {
        if messageChannel != nil { return true }
        guard let audioUnit = instantiateAudioUnit() else { return false }

        self.audioUnit = audioUnit
        messageChannel = audioUnit.auAudioUnit.messageChannel(
            for: DictationAudioUnitContract.messageChannelName
        )
        return true
    }

    private func liveMeter(from reply: [AnyHashable: Any]?) -> LiveMeter? {
        guard let reply,
              let level = reply[Key.meterLevel] as? Float,
              let rawSignalState = reply[Key.meterSignalState] as? Int,
              let signalState = KeyVoxIPCLiveMeterSignalState(rawValue: UInt8(clamping: rawSignalState)) else {
            return nil
        }
        return (level, signalState)
    }

    private func awaitOutcome() -> Outcome {
        while true {
            guard let reply = send(.poll),
                  let rawOutcome = reply[Key.outcome] as? String,
                  let outcome = DictationAudioUnitContract.Outcome(rawValue: rawOutcome) else {
                return .failed
            }

            switch outcome {
            case .pending:
                Thread.sleep(forTimeInterval: Self.outcomePollInterval)
            case .transcript:
                guard let text = reply[Key.text] as? String else { return .failed }
                return .transcript(text)
            case .noSpeech:
                return .noSpeech
            case .failed:
                return .failed
            }
        }
    }

    /// Returns nil when the extension is not connected or its process is gone.
    private func send(
        _ command: DictationAudioUnitContract.Command,
        _ payload: [AnyHashable: Any] = [:]
    ) -> [AnyHashable: Any]? {
        var message = payload
        message[Key.command] = command.rawValue
        guard let reply = messageChannel?.callAudioUnit?(message), !reply.isEmpty else {
            return nil
        }
        return reply
    }

    private func instantiateAudioUnit() -> AVAudioUnit? {
        let description = DictationAudioUnitContract.componentDescription
        // Extension components are reported shortly after the first lookup.
        let discoveryDeadline = Date().addingTimeInterval(Self.componentDiscoveryTimeout)
        while AVAudioUnitComponentManager.shared().components(matching: description).isEmpty {
            guard Date() < discoveryDeadline else { return nil }
            Thread.sleep(forTimeInterval: Self.componentDiscoveryPollInterval)
        }

        let instantiated = DispatchSemaphore(value: 0)
        nonisolated(unsafe) var audioUnit: AVAudioUnit?
        AVAudioUnit.instantiate(with: description, options: [.loadOutOfProcess]) { unit, _ in
            audioUnit = unit
            instantiated.signal()
        }
        guard instantiated.wait(timeout: .now() + Self.instantiationTimeout) == .success else {
            return nil
        }
        return audioUnit
    }
}
