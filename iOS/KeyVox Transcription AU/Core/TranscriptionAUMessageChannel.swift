import AudioToolbox
import Foundation

/// Turns the keyboard's messages into dictation session calls and answers with their results.
final class TranscriptionAUMessageChannel: NSObject, AUMessageChannel {
    private typealias Key = TranscriptionAUContract.Key

    private enum Request: Sendable {
        case begin(styleIdentifier: String?)
        case appendAudio(Data, sampleRate: Double)
        case finish
        case poll
        case cancel
        case releaseModels
    }

    private enum Reply: Sendable {
        case accepted(Bool)
        case meter(level: Float, signalState: KeyVoxIPCLiveMeterSignalState)
        case outcome(TranscriptionAUContract.Outcome, text: String?)
    }

    var callHostBlock: CallHostBlock?

    @MainActor private lazy var session = TranscriptionAUSession(
        services: TranscriptionAUServiceRegistry()
    )

    func callAudioUnit(_ message: [AnyHashable: Any]) -> [AnyHashable: Any] {
        guard let request = request(from: message) else { return [:] }
        return dictionary(for: reply(to: request))
    }

    private func request(from message: [AnyHashable: Any]) -> Request? {
        guard let rawCommand = message[Key.command] as? String,
              let command = TranscriptionAUContract.Command(rawValue: rawCommand) else {
            return nil
        }

        switch command {
        case .begin:
            return .begin(styleIdentifier: message[Key.styleIdentifier] as? String)
        case .appendAudio:
            guard let audio = message[Key.audio] as? Data,
                  let sampleRate = message[Key.sampleRate] as? Double else {
                return nil
            }
            return .appendAudio(audio, sampleRate: sampleRate)
        case .finish:
            return .finish
        case .poll:
            return .poll
        case .cancel:
            return .cancel
        case .releaseModels:
            return .releaseModels
        }
    }

    /// Messages arrive off the main thread; the session, like the app's dictation, runs on it.
    private func reply(to request: Request) -> Reply {
        if Thread.isMainThread {
            return MainActor.assumeIsolated { handle(request) }
        }
        return DispatchQueue.main.sync {
            MainActor.assumeIsolated { handle(request) }
        }
    }

    @MainActor
    private func handle(_ request: Request) -> Reply {
        switch request {
        case .begin(let styleIdentifier):
            return .accepted(session.begin(styleIdentifier: styleIdentifier))
        case .appendAudio(let audio, let sampleRate):
            guard let meter = session.append(audio: audio, sampleRate: sampleRate) else {
                return .accepted(false)
            }
            return .meter(level: meter.level, signalState: meter.signalState.ipcSignalState)
        case .finish:
            session.finish()
            return .accepted(true)
        case .poll:
            switch session.outcome {
            case .pending:
                return .outcome(.pending, text: nil)
            case .transcript(let text):
                return .outcome(.transcript, text: text)
            case .noSpeech:
                return .outcome(.noSpeech, text: nil)
            case .failed:
                return .outcome(.failed, text: nil)
            }
        case .cancel:
            session.cancel()
            return .accepted(true)
        case .releaseModels:
            session.releaseModels()
            return .accepted(true)
        }
    }

    private func dictionary(for reply: Reply) -> [AnyHashable: Any] {
        switch reply {
        case .accepted(let accepted):
            return [Key.accepted: accepted]
        case .meter(let level, let signalState):
            return [
                Key.accepted: true,
                Key.meterLevel: level,
                Key.meterSignalState: Int(signalState.rawValue),
            ]
        case .outcome(let outcome, let text):
            var dictionary: [AnyHashable: Any] = [Key.outcome: outcome.rawValue]
            if let text {
                dictionary[Key.text] = text
            }
            return dictionary
        }
    }
}
