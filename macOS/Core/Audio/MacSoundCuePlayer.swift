import AVFoundation
import Foundation

@MainActor
final class MacSoundCuePlayer: NSObject, AVAudioPlayerDelegate {
    private var activePlayers: [ObjectIdentifier: AVAudioPlayer] = [:]

    func play(named name: String, volume: Float) {
        let url = URL(fileURLWithPath: "/System/Library/Sounds")
            .appendingPathComponent(name)
            .appendingPathExtension("aiff")
        guard FileManager.default.fileExists(atPath: url.path) else {
            return
        }

        let player: AVAudioPlayer
        do {
            player = try AVAudioPlayer(contentsOf: url)
        } catch {
            return
        }

        player.delegate = self
        player.volume = volume
        player.prepareToPlay()
        let identifier = ObjectIdentifier(player)
        activePlayers[identifier] = player
        guard player.play() else {
            activePlayers.removeValue(forKey: identifier)
            return
        }
    }

    nonisolated func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        Task { @MainActor [weak self] in
            self?.activePlayers.removeValue(forKey: ObjectIdentifier(player))
        }
    }

    nonisolated func audioPlayerDecodeErrorDidOccur(_ player: AVAudioPlayer, error: Error?) {
        Task { @MainActor [weak self] in
            self?.activePlayers.removeValue(forKey: ObjectIdentifier(player))
        }
    }
}
