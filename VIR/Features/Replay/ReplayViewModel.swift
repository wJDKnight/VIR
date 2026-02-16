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

    func loadClip(_ clip: Clip, autoPlay: Bool = false) {
        guard let url = clip.fileURL else { return }
        let playerItem = AVPlayerItem(url: url)
        
        // Ensure we replace current item if player exists or create new one
        if player == nil {
            player = AVPlayer(playerItem: playerItem)
        } else {
            player?.replaceCurrentItem(with: playerItem)
        }

        // Observe time
        setupTimeObserver()

        // Get duration
        Task { @MainActor in
            if let dur = try? await playerItem.asset.load(.duration) {
                self.duration = dur.seconds
            }
        }
        
        if autoPlay {
            play()
        }
    }

    private func setupTimeObserver() {
        if let existing = timeObserver {
            player?.removeTimeObserver(existing)
        }
        
        let interval = CMTime(seconds: 0.05, preferredTimescale: 600)
        timeObserver = player?.addPeriodicTimeObserver(forInterval: interval, queue: .main) { [weak self] time in
            MainActor.assumeIsolated {
                guard let self = self else { return }
                self.currentTime = time.seconds
                
                // Check for end of playback
                if let item = self.player?.currentItem,
                   abs(time.seconds - item.duration.seconds) < 0.1,
                   self.isPlaying {
                    self.isPlaying = false
                }
            }
        }
    }

    // MARK: - Controls

    func play() {
        // If at end, restart
        if abs(currentTime - duration) < 0.1 && duration > 0 {
            seek(to: 0)
        }
        
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
