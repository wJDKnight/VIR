import SwiftUI
import AVKit

/// Video replay player with scrubber, speed control, and frame stepping.
struct ReplayPlayerView: View {
    @State private var viewModel = ReplayViewModel()
    let clip: Clip
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 0) {
            // MARK: - Video Player
            if let player = viewModel.player {
                VideoPlayer(player: player)
                    .ignoresSafeArea(edges: .top)
            } else {
                Color.black
                    .overlay {
                        ProgressView()
                            .tint(.white)
                    }
            }

            // MARK: - Controls
            VStack(spacing: 12) {
                // Timeline scrubber
                VStack(spacing: 4) {
                    Slider(
                        value: Binding(
                            get: { viewModel.currentTime },
                            set: { viewModel.seek(to: $0) }
                        ),
                        in: 0...max(viewModel.duration, 0.1)
                    )
                    .tint(.orange)

                    HStack {
                        Text(viewModel.currentTime.preciseText)
                            .font(.caption.monospacedDigit())
                        Spacer()
                        Text(viewModel.duration.preciseText)
                            .font(.caption.monospacedDigit())
                    }
                    .foregroundStyle(.secondary)
                }

                // Playback controls
                HStack(spacing: 32) {
                    // Frame step backward
                    Button {
                        viewModel.stepBackward()
                    } label: {
                        Image(systemName: "backward.frame.fill")
                            .font(.title2)
                    }

                    // Play / Pause
                    Button {
                        viewModel.togglePlayPause()
                    } label: {
                        Image(systemName: viewModel.isPlaying ? "pause.circle.fill" : "play.circle.fill")
                            .font(.system(size: 48))
                    }

                    // Frame step forward
                    Button {
                        viewModel.stepForward()
                    } label: {
                        Image(systemName: "forward.frame.fill")
                            .font(.title2)
                    }
                }
                .foregroundStyle(.white)

                // Speed control
                HStack(spacing: 8) {
                    Text("Speed:")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    ForEach(viewModel.availableRates, id: \.self) { rate in
                        Button {
                            viewModel.setRate(rate)
                        } label: {
                            Text(rate == 1.0 ? "1×" : "\(String(format: "%.2g", rate))×")
                                .font(.caption.bold())
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(
                                    viewModel.playbackRate == rate
                                        ? Color.orange
                                        : Color.gray.opacity(0.3)
                                )
                                .clipShape(Capsule())
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .padding()
            .background(.ultraThinMaterial)
        }
        .background(Color.black)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) {
                Text("Replay")
                    .font(.headline)
            }
        }
        .onAppear {
            viewModel.loadClip(clip)
        }
        .onDisappear {
            viewModel.cleanup()
        }
    }
}
