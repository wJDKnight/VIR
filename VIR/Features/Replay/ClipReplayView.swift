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
    @State private var drawingMode: DrawingMode = .pen
    
    // Straight Line State
    @State private var straightLines: [LineSegment] = []
    
    // Angle Measurement State
    @State private var angleMeasurements: [AngleMeasurement] = []
    
    // Color/width state for non-PK overlays (synced via toolbar)
    @State private var overlayColor: Color = .red
    @State private var overlayLineWidth: CGFloat = 5.0
    
    // Optional: Auto-play on appear
    var autoPlay: Bool = true
    
    // Controls Visibility
    @State private var showControls: Bool = true
    
    var body: some View {
        ZStack(alignment: .bottom) {
            // MARK: - Video Player Area
             GeometryReader { proxy in
                 ZStack {
                    Color.black
                    
                    if proxy.size.width > 0 && proxy.size.height > 0 {
                        if let player = viewModel.player {
                            VideoPlayer(player: player)
                                .frame(width: proxy.size.width, height: proxy.size.height)
                        } else {
                            ContentUnavailableView("Loading Video...", systemImage: "video")
                                .frame(width: proxy.size.width, height: proxy.size.height)
                        }
                         
                        // MARK: - Drawing Overlays
                        // PencilKit canvas — interactive only in pen mode, read-only otherwise
                        if isDrawing && drawingMode == .pen {
                            DrawingCanvasView(
                                drawing: $drawing,
                                tool: currentTool,
                                isUserInteractionEnabled: true
                            )
                            .allowsHitTesting(true)
                            .frame(width: proxy.size.width, height: proxy.size.height)
                        } else if !drawing.bounds.isEmpty {
                             // Read-only freehand drawing (visible in all modes)
                            DrawingCanvasView(
                                drawing: $drawing,
                                tool: currentTool,
                                isUserInteractionEnabled: false
                            )
                            .allowsHitTesting(false)
                            .frame(width: proxy.size.width, height: proxy.size.height)
                        }
                        
                        // Straight Line overlay — interactive only in line mode
                        if !straightLines.isEmpty || (isDrawing && drawingMode == .line) {
                            StraightLineOverlayView(
                                lines: $straightLines,
                                currentColor: overlayColor,
                                currentLineWidth: overlayLineWidth,
                                isInteractive: isDrawing && drawingMode == .line,
                                isErasing: false
                            )
                            .allowsHitTesting(isDrawing && drawingMode == .line)
                            .frame(width: proxy.size.width, height: proxy.size.height)
                        }
                        
                        // Angle Measurement overlay — interactive only in angle mode
                        if !angleMeasurements.isEmpty || (isDrawing && drawingMode == .angle) {
                            AngleMeasurementOverlayView(
                                measurements: $angleMeasurements,
                                currentColor: overlayColor,
                                currentLineWidth: overlayLineWidth,
                                isInteractive: isDrawing && drawingMode == .angle,
                                isErasing: false
                            )
                            .allowsHitTesting(isDrawing && drawingMode == .angle)
                            .frame(width: proxy.size.width, height: proxy.size.height)
                        }
                        
                        // MARK: - Unified Eraser Overlay
                        // Single overlay that handles erasing for ALL drawing types
                        if isDrawing && drawingMode == .eraser {
                            Color.clear
                                .contentShape(Rectangle())
                                .onTapGesture { location in
                                    eraseNearest(at: location)
                                }
                                .allowsHitTesting(true)
                                .frame(width: proxy.size.width, height: proxy.size.height)
                        }
                    }
                }
            }
            .ignoresSafeArea()
            // MARK: - Controls
            // Controls overlay
            if isDrawing {
                DrawingToolBar(
                    currentTool: $currentTool,
                    isDrawing: $isDrawing,
                    drawing: $drawing,
                    drawingMode: $drawingMode,
                    overlayColor: $overlayColor,
                    overlayLineWidth: $overlayLineWidth,
                    straightLines: $straightLines,
                    angleMeasurements: $angleMeasurements,
                    onUndoLine: {
                        if !straightLines.isEmpty {
                            straightLines.removeLast()
                        }
                    },
                    onUndoAngle: {
                        if !angleMeasurements.isEmpty {
                            angleMeasurements.removeLast()
                        }
                    }
                )
                .transition(.move(edge: .bottom))
                .padding()
            } else if showControls {
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
                        }
                    }
                    
                    Divider()
                        .background(.gray.opacity(0.5))
                    
                    // Trim Controls
                    HStack(spacing: 16) {
                        Text("Trim:")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        
                        Button {
                            // Ensure start < end if end is set
                            if let end = viewModel.trimEnd, viewModel.currentTime >= end {
                                return
                            }
                            clip.trimStart = viewModel.currentTime
                            viewModel.setTrim(start: clip.trimStart, end: viewModel.trimEnd)
                        } label: {
                            Text("Set Start")
                                .font(.caption2.bold())
                                .padding(.horizontal, 10)
                                .padding(.vertical, 6)
                                .background(clip.trimStart != nil ? Color.green : Color.gray.opacity(0.3))
                                .clipShape(Capsule())
                        }
                        
                        Button {
                            // Ensure end > start if start is set
                            if let start = viewModel.trimStart, viewModel.currentTime <= start {
                                return
                            }
                            clip.trimEnd = viewModel.currentTime
                            viewModel.setTrim(start: viewModel.trimStart, end: clip.trimEnd)
                        } label: {
                            Text("Set End")
                                .font(.caption2.bold())
                                .padding(.horizontal, 10)
                                .padding(.vertical, 6)
                                .background(clip.trimEnd != nil ? Color.green : Color.gray.opacity(0.3))
                                .clipShape(Capsule())
                        }
                        
                        if clip.trimStart != nil || clip.trimEnd != nil {
                            Button {
                                clip.trimStart = nil
                                clip.trimEnd = nil
                                viewModel.setTrim(start: nil, end: nil)
                            } label: {
                                Text("Clear")
                                    .font(.caption2.bold())
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 6)
                                    .background(Color.red.opacity(0.8))
                                    .clipShape(Capsule())
                            }
                        }
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(.white)
                }
                .padding()
                .background(.ultraThinMaterial)
                .transition(.move(edge: .bottom))
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.black)
        .ignoresSafeArea()
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) {
                Text(isDrawing ? "Drawing Mode" : "Clip Replay")
                    .font(.headline)
                    .foregroundStyle(.white)
            }
            
            ToolbarItem(placement: .topBarTrailing) {
                HStack(spacing: 16) {
                    if !isDrawing {
                        Button {
                            withAnimation {
                                showControls.toggle()
                            }
                        } label: {
                            Image(systemName: showControls ? "eye" : "eye.slash")
                                .foregroundStyle(.white)
                        }
                    }
                    
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
    
    // MARK: - Unified Eraser Logic
    
    /// Finds and removes the nearest drawing element (line, angle, or PK stroke) near the tap point.
    private func eraseNearest(at point: CGPoint) {
        let lineThreshold: CGFloat = 30
        let angleThreshold: CGFloat = 40
        let strokeThreshold: CGFloat = 25
        
        var bestDist: CGFloat = .greatestFiniteMagnitude
        var bestType: ErasableType?
        var bestIndex: Int?
        
        // Check lines
        for (i, line) in straightLines.enumerated() {
            let d = distanceFromPoint(point, toSegmentFrom: line.start, to: line.end)
            if d < lineThreshold && d < bestDist {
                bestDist = d
                bestType = .line
                bestIndex = i
            }
        }
        
        // Check angles (points + rays)
        for (i, m) in angleMeasurements.enumerated() {
            // Check proximity to the three points
            for pt in [m.p1, m.vertex, m.p3] {
                let d = hypot(point.x - pt.x, point.y - pt.y)
                if d < angleThreshold && d < bestDist {
                    bestDist = d
                    bestType = .angle
                    bestIndex = i
                }
            }
            // Check proximity to ray segments
            let d1 = distanceFromPoint(point, toSegmentFrom: m.vertex, to: m.p1)
            let d2 = distanceFromPoint(point, toSegmentFrom: m.vertex, to: m.p3)
            let minRayDist = min(d1, d2)
            if minRayDist < angleThreshold && minRayDist < bestDist {
                bestDist = minRayDist
                bestType = .angle
                bestIndex = i
            }
        }
        
        // Check PK strokes
        for (i, stroke) in drawing.strokes.enumerated() {
            let bounds = stroke.renderBounds.insetBy(dx: -strokeThreshold, dy: -strokeThreshold)
            if bounds.contains(point) {
                // Use center distance as a rough priority
                let center = CGPoint(x: stroke.renderBounds.midX, y: stroke.renderBounds.midY)
                let d = hypot(point.x - center.x, point.y - center.y)
                if d < bestDist {
                    bestDist = d
                    bestType = .stroke
                    bestIndex = i
                }
            }
        }
        
        // Remove the closest match
        guard let type = bestType, let idx = bestIndex else { return }
        switch type {
        case .line:
            straightLines.remove(at: idx)
        case .angle:
            angleMeasurements.remove(at: idx)
        case .stroke:
            var newDrawing = drawing
            newDrawing.strokes.remove(at: idx)
            drawing = newDrawing
        }
    }
    
    /// Perpendicular distance from a point to a line segment.
    private func distanceFromPoint(_ p: CGPoint, toSegmentFrom a: CGPoint, to b: CGPoint) -> CGFloat {
        let dx = b.x - a.x
        let dy = b.y - a.y
        let lengthSq = dx * dx + dy * dy
        guard lengthSq > 0 else { return hypot(p.x - a.x, p.y - a.y) }
        var t = ((p.x - a.x) * dx + (p.y - a.y) * dy) / lengthSq
        t = max(0, min(1, t))
        let projX = a.x + t * dx
        let projY = a.y + t * dy
        return hypot(p.x - projX, p.y - projY)
    }
    
    private enum ErasableType {
        case line, angle, stroke
    }
}
