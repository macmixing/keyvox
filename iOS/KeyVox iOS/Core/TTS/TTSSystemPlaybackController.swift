import Foundation
import MediaPlayer
import UIKit

@MainActor
final class TTSSystemPlaybackController {
    var onPlay: (() -> Void)?
    var onPause: (() -> Void)?
    var onTogglePlayPause: (() -> Void)?
    var onSeekToTime: ((TimeInterval) -> Void)?

    private let commandCenter: MPRemoteCommandCenter
    private let nowPlayingInfoCenter: MPNowPlayingInfoCenter

    private var playTarget: Any?
    private var pauseTarget: Any?
    private var togglePlayPauseTarget: Any?
    private var changePlaybackPositionTarget: Any?

    private var lastTitle: String?
    private var lastVoiceName: String?
    private var lastIsPlaying = false
    private var lastIsReplay = false
    private var lastElapsedBucket: Int?
    private var lastDurationBucket: Int?
    private lazy var artwork: MPMediaItemArtwork? = Self.makeArtwork()

    init(
        commandCenter: MPRemoteCommandCenter = .shared(),
        nowPlayingInfoCenter: MPNowPlayingInfoCenter = .default()
    ) {
        self.commandCenter = commandCenter
        self.nowPlayingInfoCenter = nowPlayingInfoCenter
        configureRemoteCommands()
        updateRemoteCommandAvailability(isActive: false, isPlaying: false, canSeek: false)
        UIApplication.shared.beginReceivingRemoteControlEvents()
    }

    deinit {
        if let playTarget {
            commandCenter.playCommand.removeTarget(playTarget)
        }
        if let pauseTarget {
            commandCenter.pauseCommand.removeTarget(pauseTarget)
        }
        if let togglePlayPauseTarget {
            commandCenter.togglePlayPauseCommand.removeTarget(togglePlayPauseTarget)
        }
        if let changePlaybackPositionTarget {
            commandCenter.changePlaybackPositionCommand.removeTarget(changePlaybackPositionTarget)
        }
    }

    func update(
        displayText: String,
        voiceName: String?,
        isPlaying: Bool,
        isReplay: Bool,
        elapsedSeconds: TimeInterval,
        durationSeconds: TimeInterval?
    ) {
        let title = condensedTitle(from: displayText)
        let elapsed = max(0, elapsedSeconds)
        let duration = durationSeconds.map { max(0, $0) }
        let elapsedBucket = Int((elapsed * 2).rounded(.toNearestOrAwayFromZero))
        let durationBucket = duration.map { Int(($0 * 2).rounded(.toNearestOrAwayFromZero)) }
        let didChangeSnapshot =
            title != lastTitle
            || voiceName != lastVoiceName
            || isPlaying != lastIsPlaying
            || isReplay != lastIsReplay
            || elapsedBucket != lastElapsedBucket
            || durationBucket != lastDurationBucket

        updateRemoteCommandAvailability(
            isActive: true,
            isPlaying: isPlaying,
            canSeek: isReplay && (duration ?? 0) > 0
        )

        guard didChangeSnapshot else { return }

        var info: [String: Any] = [
            MPMediaItemPropertyTitle: title,
            MPMediaItemPropertyAlbumTitle: "KeyVox Speak",
            MPNowPlayingInfoPropertyMediaType: MPNowPlayingInfoMediaType.audio.rawValue,
            MPNowPlayingInfoPropertyElapsedPlaybackTime: elapsed,
            MPNowPlayingInfoPropertyPlaybackRate: isPlaying ? 1.0 : 0.0,
            MPNowPlayingInfoPropertyDefaultPlaybackRate: 1.0,
            MPNowPlayingInfoPropertyIsLiveStream: isReplay == false
        ]

        if let voiceName, voiceName.isEmpty == false {
            info[MPMediaItemPropertyArtist] = voiceName
        }

        if let duration, isReplay {
            info[MPMediaItemPropertyPlaybackDuration] = duration
        }

        if let artwork {
            info[MPMediaItemPropertyArtwork] = artwork
        }

        nowPlayingInfoCenter.nowPlayingInfo = info
        nowPlayingInfoCenter.playbackState = isPlaying ? .playing : .paused

        Self.log(
            "Published now playing info titleLength=\(title.count) voice=\(voiceName ?? "nil") isPlaying=\(isPlaying) isReplay=\(isReplay) elapsed=\(String(format: "%.2f", elapsed)) duration=\(duration.map { String(format: "%.2f", $0) } ?? "nil")"
        )

        lastTitle = title
        lastVoiceName = voiceName
        lastIsPlaying = isPlaying
        lastIsReplay = isReplay
        lastElapsedBucket = elapsedBucket
        lastDurationBucket = durationBucket
    }

    func clear() {
        updateRemoteCommandAvailability(isActive: false, isPlaying: false, canSeek: false)
        nowPlayingInfoCenter.nowPlayingInfo = nil
        Self.log("Cleared now playing info.")

        lastTitle = nil
        lastVoiceName = nil
        lastIsPlaying = false
        lastIsReplay = false
        lastElapsedBucket = nil
        lastDurationBucket = nil
    }

    private func configureRemoteCommands() {
        playTarget = commandCenter.playCommand.addTarget { [weak self] _ in
            Self.log("Received remote play command.")
            if Thread.isMainThread {
                self?.onPlay?()
            } else {
                DispatchQueue.main.sync {
                    self?.onPlay?()
                }
            }
            return .success
        }

        pauseTarget = commandCenter.pauseCommand.addTarget { [weak self] _ in
            Self.log("Received remote pause command.")
            if Thread.isMainThread {
                self?.onPause?()
            } else {
                DispatchQueue.main.sync {
                    self?.onPause?()
                }
            }
            return .success
        }

        togglePlayPauseTarget = commandCenter.togglePlayPauseCommand.addTarget { [weak self] _ in
            Self.log("Received remote togglePlayPause command.")
            if Thread.isMainThread {
                self?.onTogglePlayPause?()
            } else {
                DispatchQueue.main.sync {
                    self?.onTogglePlayPause?()
                }
            }
            return .success
        }

        changePlaybackPositionTarget = commandCenter.changePlaybackPositionCommand.addTarget { [weak self] event in
            guard let positionEvent = event as? MPChangePlaybackPositionCommandEvent else {
                Self.log("Received remote changePlaybackPosition command with unexpected event type.")
                return .commandFailed
            }
            Self.log(
                "Received remote changePlaybackPosition command position=\(String(format: "%.2f", positionEvent.positionTime))"
            )
            if Thread.isMainThread {
                self?.onSeekToTime?(positionEvent.positionTime)
            } else {
                DispatchQueue.main.sync {
                    self?.onSeekToTime?(positionEvent.positionTime)
                }
            }
            return .success
        }

        commandCenter.stopCommand.isEnabled = false
        commandCenter.nextTrackCommand.isEnabled = false
        commandCenter.previousTrackCommand.isEnabled = false
        commandCenter.skipForwardCommand.isEnabled = false
        commandCenter.skipBackwardCommand.isEnabled = false
        commandCenter.seekForwardCommand.isEnabled = false
        commandCenter.seekBackwardCommand.isEnabled = false
        commandCenter.changePlaybackRateCommand.isEnabled = false
        commandCenter.changeRepeatModeCommand.isEnabled = false
        commandCenter.changeShuffleModeCommand.isEnabled = false
        commandCenter.ratingCommand.isEnabled = false
        commandCenter.likeCommand.isEnabled = false
        commandCenter.dislikeCommand.isEnabled = false
        commandCenter.bookmarkCommand.isEnabled = false
    }

    private func updateRemoteCommandAvailability(
        isActive: Bool,
        isPlaying: Bool,
        canSeek: Bool
    ) {
        commandCenter.playCommand.isEnabled = isActive && isPlaying == false
        commandCenter.pauseCommand.isEnabled = isActive && isPlaying
        commandCenter.togglePlayPauseCommand.isEnabled = isActive
        commandCenter.changePlaybackPositionCommand.isEnabled = isActive && canSeek
        Self.log(
            "Updated remote command availability active=\(isActive) playing=\(isPlaying) canSeek=\(canSeek) playEnabled=\(commandCenter.playCommand.isEnabled) pauseEnabled=\(commandCenter.pauseCommand.isEnabled) toggleEnabled=\(commandCenter.togglePlayPauseCommand.isEnabled) seekEnabled=\(commandCenter.changePlaybackPositionCommand.isEnabled)"
        )
    }

    private func condensedTitle(from displayText: String) -> String {
        let collapsed = displayText
            .components(separatedBy: .whitespacesAndNewlines)
            .filter { $0.isEmpty == false }
            .joined(separator: " ")

        guard collapsed.count > 96 else { return collapsed }
        let endIndex = collapsed.index(collapsed.startIndex, offsetBy: 96)
        return String(collapsed[..<endIndex]).trimmingCharacters(in: .whitespacesAndNewlines) + "..."
    }

    private static func makeArtwork() -> MPMediaItemArtwork? {
        guard let image = UIImage(named: "keyvox-speak-art") else {
            log("Failed to load now playing artwork asset keyvox-speak-art.")
            return nil
        }

        log("Loaded now playing artwork asset keyvox-speak-art size=\(image.size.width)x\(image.size.height)")
        return MPMediaItemArtwork(boundsSize: image.size) { _ in image }
    }

    private static func log(_ message: String) {
        #if DEBUG
        NSLog("[TTSSystemPlaybackController] %@", message)
        #endif
    }
}
