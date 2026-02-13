import Foundation
import AVFoundation
import Combine

/// ViewModel for the replay player.
@Observable
@MainActor
class ReplayViewModel {
    var isPlaying = false
    var currentTime: TimeInterval = 0
    var duration: TimeInterval = 0
    var playbackRate: Float = 1.0

    let availableRates: [Float] = [0.25, 0.5, 0.75, 1.0, 2.0]

    private(set) var player: AVPlayer?
    private var timeObserver: Any?

    // MARK: - Load

    func loadClip(_ clip: Clip) {
        guard let url = clip.fileURL else { return }
        let playerItem = AVPlayerItem(url: url)
        player = AVPlayer(playerItem: playerItem)

        // Observe time
        let interval = CMTime(seconds: 0.05, preferredTimescale: 600)
        timeObserver = player?.addPeriodicTimeObserver(forInterval: interval, queue: .main) { [weak self] time in
            MainActor.assumeIsolated {
                self?.currentTime = time.seconds
            }
        }

        // Get duration
        Task { @MainActor in
            if let dur = try? await playerItem.asset.load(.duration) {
                self.duration = dur.seconds
            }
        }
    }

    // MARK: - Controls

    func play() {
        player?.rate = playbackRate
        isPlaying = true
    }

    func pause() {
        player?.pause()
        isPlaying = false
    }

    func togglePlayPause() {
        isPlaying ? pause() : play()
    }

    func seek(to time: TimeInterval) {
        let cmTime = CMTime(seconds: time, preferredTimescale: 600)
        player?.seek(to: cmTime, toleranceBefore: .zero, toleranceAfter: .zero)
        currentTime = time
    }

    func setRate(_ rate: Float) {
        playbackRate = rate
        if isPlaying {
            player?.rate = rate
        }
    }

    /// Step forward one frame (at current fps)
    func stepForward(fps: Int = 30) {
        pause()
        let frameTime = 1.0 / Double(fps)
        seek(to: min(currentTime + frameTime, duration))
    }

    /// Step backward one frame
    func stepBackward(fps: Int = 30) {
        pause()
        let frameTime = 1.0 / Double(fps)
        seek(to: max(currentTime - frameTime, 0))
    }

    // MARK: - Cleanup

    func cleanup() {
        if let observer = timeObserver {
            player?.removeTimeObserver(observer)
        }
        player?.pause()
        player = nil
        timeObserver = nil
    }
}
