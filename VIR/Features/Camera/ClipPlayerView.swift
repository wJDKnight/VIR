import SwiftUI
import AVKit

struct ClipPlayerView: View {
    let clip: Clip
    @State private var player: AVPlayer?
    @State private var isPlaying = false
    @State private var currentTime: Double = 0.0
    @State private var duration: Double = 0.0
    @State private var playbackRate: Float = 1.0
    
    // Timer for updating scrubber
    let timeObserver = Timer.publish(every: 0.1, on: .main, in: .common).autoconnect()
    
    var body: some View {
        VStack(spacing: 0) {
            // Video Area
            ZStack {
                Color.black.edgesIgnoringSafeArea(.all)
                
                if let player = player {
                    VideoPlayer(player: player)
                        .onAppear {
                            // Don't auto-play, let user choose or maybe auto-play once
                            player.play()
                            isPlaying = true
                        }
                        .onDisappear {
                            player.pause()
                            isPlaying = false
                        }
                } else {
                    ContentUnavailableView("Video Not Found", systemImage: "video.slash")
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            
            // Controls Area
            VStack(spacing: 12) {
                // Scrubber
                HStack {
                    Text(formatTime(currentTime))
                        .font(.caption)
                        .monospacedDigit()
                        .foregroundStyle(.secondary)
                    
                    Slider(value: Binding(get: {
                        currentTime
                    }, set: { newValue in
                        currentTime = newValue
                        seek(to: newValue)
                    }), in: 0...max(duration, 0.01))
                    
                    Text(formatTime(duration))
                        .font(.caption)
                        .monospacedDigit()
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal)
                
                // Playback Buttons
                HStack(spacing: 40) {
                    // Frame Back
                    Button {
                        stepFrame(by: -1)
                    } label: {
                        Image(systemName: "backward.frame")
                            .font(.title2)
                    }
                    
                    // Play/Pause
                    Button {
                        togglePlayPause()
                    } label: {
                        Image(systemName: isPlaying ? "pause.circle.fill" : "play.circle.fill")
                            .font(.system(size: 50))
                    }
                    
                    // Frame Forward
                    Button {
                        stepFrame(by: 1)
                    } label: {
                        Image(systemName: "forward.frame")
                            .font(.title2)
                    }
                }
                
                // Speed Control
                Picker("Playback Speed", selection: $playbackRate) {
                    Text("0.25x").tag(Float(0.25))
                    Text("0.5x").tag(Float(0.5))
                    Text("1.0x").tag(Float(1.0))
                    Text("2.0x").tag(Float(2.0))
                }
                .pickerStyle(.segmented)
                .padding(.horizontal)
                .onChange(of: playbackRate) { _, newRate in
                    player?.rate = isPlaying ? newRate : 0.0
                }
            }
            .padding(.vertical)
            .background(.ultraThinMaterial)
        }
        .navigationTitle("Clip Playback")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            setupPlayer()
        }
        .onReceive(timeObserver) { _ in
            guard let player = player, isPlaying else { return }
            currentTime = player.currentTime().seconds
            // Sync isPlaying state in case it stopped naturally
            if player.timeControlStatus == .paused && isPlaying {
                // If we reached the end, maybe reset or showing pause
                if abs(currentTime - duration) < 0.1 {
                    isPlaying = false
                }
            }
        }
    }
    
    private func setupPlayer() {
        guard let url = clip.fileURL else {
            print("Clip file path not found for clip: \(clip.id)")
            return
        }
        print("Playing clip from: \(url.path)")
        
        let playerItem = AVPlayerItem(url: url)
        let player = AVPlayer(playerItem: playerItem)
        self.player = player
        
        // Load duration
        Task {
            if let duration = try? await playerItem.asset.load(.duration) {
                await MainActor.run {
                    self.duration = duration.seconds
                }
            }
        }
    }
    
    private func togglePlayPause() {
        guard let player = player else { return }
        
        if isPlaying {
            player.pause()
            isPlaying = false
        } else {
            // If at end, restart
            if abs(currentTime - duration) < 0.1 {
                seek(to: 0)
            }
            player.playImmediately(atRate: playbackRate)
            isPlaying = true
        }
    }
    
    private func seek(to time: Double) {
        guard let player = player else { return }
        let cmTime = CMTime(seconds: time, preferredTimescale: 600)
        player.seek(to: cmTime, toleranceBefore: .zero, toleranceAfter: .zero)
    }
    
    private func stepFrame(by count: Int) {
        guard let player = player else { return }
        player.pause()
        isPlaying = false
        player.currentItem?.step(byCount: count)
        
        // Update current time immediately
        if let newTime = player.currentItem?.currentTime() {
            currentTime = newTime.seconds
        }
    }
    
    private func formatTime(_ seconds: Double) -> String {
        let m = Int(seconds) / 60
        let s = Int(seconds) % 60
        let ms = Int((seconds.truncatingRemainder(dividingBy: 1)) * 100)
        return String(format: "%02d:%02d.%02d", m, s, ms)
    }
}
