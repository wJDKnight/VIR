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
    
    // Active Trim Boundaries
    var trimStart: TimeInterval?
    var trimEnd: TimeInterval?

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

        // Load trim boundaries
        self.trimStart = clip.trimStart
        self.trimEnd = clip.trimEnd

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
                
                // Check for end of playback (or end of trim window)
                if self.isPlaying {
                    if let end = self.trimEnd {
                        if time.seconds >= end - 0.05 { // Tiny threshold to ensure it doesn't overshoot
                            self.seek(to: end)
                            self.pause()
                        }
                    } else if let item = self.player?.currentItem {
                        if abs(time.seconds - item.duration.seconds) < 0.1 {
                            self.isPlaying = false
                        }
                    }
                }
            }
        }
    }

    // MARK: - Controls

    func play() {
        // If at end or past trimEnd, restart at trimStart or 0
        let currentBoundaryEnd = trimEnd ?? duration
        let currentBoundaryStart = trimStart ?? 0.0
        
        if currentTime >= currentBoundaryEnd - 0.1 && currentBoundaryEnd > 0 {
            seek(to: currentBoundaryStart)
        } else if currentTime < currentBoundaryStart {
            seek(to: currentBoundaryStart)
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
        let upperLimit = trimEnd ?? duration
        seek(to: min(currentTime + frameTime, upperLimit))
    }

    /// Step backward one frame
    func stepBackward(fps: Int = 30) {
        pause()
        let frameTime = 1.0 / Double(fps)
        let lowerLimit = trimStart ?? 0.0
        seek(to: max(currentTime - frameTime, lowerLimit))
    }
    
    // MARK: - Trim API
    
    func setTrim(start: TimeInterval?, end: TimeInterval?) {
        self.trimStart = start
        self.trimEnd = end
        
        // Adjust current playback head if it's now out of bounds
        if let s = start, currentTime < s {
            seek(to: s)
        }
        if let e = end, currentTime > e {
            seek(to: e)
        }
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
