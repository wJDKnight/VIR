import SwiftUI
import AVKit
import PencilKit

/// A reusable view for playing back clips using ReplayViewModel.
/// Replaces ClipPlayerView and ReplayPlayerView.
struct ClipReplayView: View {
    let clip: Clip
    @State private var viewModel = ReplayViewModel()
    @Environment(\.dismiss) private var dismiss
    
    // Drawing State
    @State private var isDrawing = false
    @State private var canvasView = PKCanvasView()
    @State private var drawing = PKDrawing()
    @State private var currentTool: PKTool = PKInkingTool(.pen, color: .red, width: 5)
    
    // Optional: Auto-play on appear
    var autoPlay: Bool = true
    
    var body: some View {
        VStack(spacing: 0) {
            // MARK: - Video Player Area
             ZStack {
                Color.black.edgesIgnoringSafeArea(.all)
                
                if let player = viewModel.player {
                    VideoPlayer(player: player)
                        .ignoresSafeArea(edges: .top)
                } else {
                    ContentUnavailableView("Loading Video...", systemImage: "video")
                }
                 
                // Drawing Overlay
                if isDrawing {
                    DrawingCanvasView(
                        drawing: $drawing,
                        tool: currentTool,
                        isUserInteractionEnabled: true
                    )
                    .allowsHitTesting(true) // Ensure it receives touches
                } else if !drawing.bounds.isEmpty {
                     // Show drawing even if not "isDrawing" mode (read-only)
                    DrawingCanvasView(
                        drawing: $drawing,
                        tool: currentTool,
                        isUserInteractionEnabled: false
                    )
                    .allowsHitTesting(false)
                 }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .overlay(alignment: .bottom) {
                if isDrawing {
                    DrawingToolBar(
                        currentTool: $currentTool,
                        isDrawing: $isDrawing,
                        drawing: $drawing
                    )
                    .transition(.move(edge: .bottom))
                    .padding()
                }
            }
            
            // MARK: - Controls
            if !isDrawing {
                VStack(spacing: 12) {
                    // Scrubber
                    VStack(spacing: 4) {
                        Slider(
                            value: Binding(
                                get: { viewModel.currentTime },
                                set: { viewModel.seek(to: $0) }
                            ),
                            in: 0...max(viewModel.duration, 0.01)
                        )
                        .tint(.orange)
                        
                        HStack {
                            Text(formatTime(viewModel.currentTime))
                                .font(.caption.monospacedDigit())
                            Spacer()
                            Text(formatTime(viewModel.duration))
                                .font(.caption.monospacedDigit())
                        }
                        .foregroundStyle(.secondary)
                    }
                    .padding(.horizontal)
                    
                    // Playback Buttons
                    HStack(spacing: 32) {
                        // Frame Background
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
                        
                        // Frame Forward
                        Button {
                            viewModel.stepForward()
                        } label: {
                            Image(systemName: "forward.frame.fill")
                                .font(.title2)
                        }
                    }
                    .foregroundStyle(.white)
                    
                    // Speed Control
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
                .transition(.move(edge: .bottom))
            }
        }
        .background(Color.black)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) {
                Text(isDrawing ? "Drawing Mode" : "Clip Replay")
                    .font(.headline)
                    .foregroundStyle(.white)
            }
            
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    withAnimation {
                        isDrawing.toggle()
                        if isDrawing {
                             viewModel.pause()
                        }
                    }
                } label: {
                    Image(systemName: "pencil.tip.crop.circle")
                        .foregroundStyle(isDrawing ? .orange : .white)
                }
            }
        }
        .onAppear {
            viewModel.loadClip(clip, autoPlay: autoPlay)
        }
        .onDisappear {
            viewModel.cleanup()
        }
    }
    
    private func formatTime(_ seconds: Double) -> String {
        let m = Int(seconds) / 60
        let s = Int(seconds) % 60
        let ms = Int((seconds.truncatingRemainder(dividingBy: 1)) * 100)
        return String(format: "%02d:%02d.%02d", m, s, ms)
    }
}
