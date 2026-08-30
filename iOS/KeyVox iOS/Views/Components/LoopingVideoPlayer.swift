import SwiftUI
import AVFoundation

struct LoopingVideoPlayer: UIViewRepresentable {
    let videoName: String
    let videoType: String = "mov"
    let isPlaying: Bool = true
    @Binding var isReady: Bool

    func makeUIView(context: Context) -> UIView {
        let view = LoopingVideoUIView(
            videoName: videoName, 
            videoType: videoType, 
            isPlaying: isPlaying,
            isReady: $isReady
        )
        return view
    }

    func updateUIView(_ uiView: UIView, context: Context) {
        guard let videoView = uiView as? LoopingVideoUIView else { return }
        videoView.setPlaying(isPlaying)
    }
}

private class LoopingVideoUIView: UIView {
    private let playerLayer = AVPlayerLayer()
    private var playerLooper: AVPlayerLooper?
    private var readyToDisplayObserver: NSKeyValueObservation?
    private var didBecomeActiveObserver: NSObjectProtocol?
    private var isReady: Binding<Bool>
    private var player: AVQueuePlayer?
    private var isPlaying: Bool

    init(
        videoName: String,
        videoType: String,
        isPlaying: Bool,
        isReady: Binding<Bool>
    ) {
        self.isReady = isReady
        self.isPlaying = isPlaying
        super.init(frame: .zero)

        guard let fileURL = Bundle.main.url(forResource: videoName, withExtension: videoType) else {
            #if DEBUG
            print("Error: Could not find video file \(videoName).\(videoType)")
            #endif
            return
        }

        let asset = AVURLAsset(url: fileURL)
        let item = AVPlayerItem(asset: asset)
        
        let player = AVQueuePlayer(playerItem: item)
        player.automaticallyWaitsToMinimizeStalling = false
        self.player = player
        
        playerLayer.player = player
        playerLayer.videoGravity = .resizeAspect
        playerLayer.backgroundColor = UIColor.clear.cgColor
        
        // We keep it visible from the start because it's physically behind the static image.
        // This ensures it's "warming up" while the image is blocking it.
        playerLayer.opacity = 1
        
        layer.addSublayer(playerLayer)

        // Observe when the first frame is actually ready to be seen
        readyToDisplayObserver = playerLayer.observe(\.isReadyForDisplay, options: [.new]) { [weak self] (layer, change) in
            if change.newValue == true {
                DispatchQueue.main.async {
                    // We wait a generous 0.2s to ensure the video has officially rendered
                    // at least one frame into the hardware buffer before we hide the image.
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                        self?.isReady.wrappedValue = true
                    }
                }
            }
        }

        playerLooper = AVPlayerLooper(player: player, templateItem: item)
        if isPlaying {
            player.play()
        } else {
            player.pause()
            player.seek(to: .zero)
        }

        didBecomeActiveObserver = NotificationCenter.default.addObserver(
            forName: UIApplication.didBecomeActiveNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.resumePlaybackIfNeeded()
        }
        
        backgroundColor = .clear
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        playerLayer.frame = bounds
        CATransaction.commit()
    }

    func setPlaying(_ shouldPlay: Bool) {
        guard shouldPlay != isPlaying, let player else { return }
        isPlaying = shouldPlay

        if shouldPlay {
            player.seek(to: .zero) { [weak self, weak player] _ in
                guard self?.isPlaying == true else { return }
                player?.play()
            }
        } else {
            player.pause()
            player.seek(to: .zero)
        }
    }

    private func resumePlaybackIfNeeded() {
        guard isPlaying else { return }
        player?.play()
    }
    
    deinit {
        readyToDisplayObserver?.invalidate()
        if let didBecomeActiveObserver {
            NotificationCenter.default.removeObserver(didBecomeActiveObserver)
        }
    }
}
