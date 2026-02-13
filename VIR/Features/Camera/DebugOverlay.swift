import SwiftUI

/// On-screen debug overlay showing real-time camera/buffer stats.
/// Toggle visibility with a triple-tap on the camera screen.
struct DebugOverlay: View {
    var viewModel: CameraViewModel
    @State private var captureFPS: Double = 0
    @State private var lastFrameCount: Int = 0
    @State private var timer: Timer?

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("🔧 DEBUG")
                .font(.system(size: 11, weight: .bold, design: .monospaced))
                .foregroundStyle(.yellow)

            Group {
                stat("Capture FPS", "\(String(format: "%.1f", captureFPS))")
                stat("Buffer Frames", "\(viewModel.compressedBuffer?.totalFramesWritten ?? 0)")
                stat("Delay Frames", "\(viewModel.compressedBuffer?.delayFrameCount ?? 0)")
                stat("Fill Level", "\(String(format: "%.0f%%", (viewModel.compressedBuffer?.fillLevel ?? 0) * 100))")
                stat("Delay Ready", viewModel.delayReady ? "✅" : "⏳")
                stat("Recording", viewModel.isRecording ? "🔴" : "⏹")
                stat("Elapsed", String(format: "%.1fs", viewModel.elapsedTime))
            }
        }
        .padding(10)
        .background(.black.opacity(0.7))
        .cornerRadius(10)
        .onAppear { startFPSTimer() }
        .onDisappear { timer?.invalidate() }
    }

    private func stat(_ label: String, _ value: String) -> some View {
        HStack(spacing: 6) {
            Text(label)
                .frame(width: 100, alignment: .leading)
            Text(value)
                .foregroundStyle(.green)
        }
        .font(.system(size: 10, weight: .medium, design: .monospaced))
        .foregroundStyle(.white)
    }

    private func startFPSTimer() {
        lastFrameCount = viewModel.compressedBuffer?.totalFramesWritten ?? 0
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [self] _ in
            Task { @MainActor in
                let current = viewModel.compressedBuffer?.totalFramesWritten ?? 0
                captureFPS = Double(current - lastFrameCount)
                lastFrameCount = current
            }
        }
    }
}
