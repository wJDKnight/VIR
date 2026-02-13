import SwiftUI
import AVFoundation
import CoreImage
import CoreVideo

/// UIViewRepresentable that displays delayed video frames from the CompressedFrameBuffer
/// using a simple UIImageView driven by CADisplayLink.
struct DelayedPlaybackView: UIViewRepresentable {
    let compressedBuffer: CompressedFrameBuffer

    func makeUIView(context: Context) -> DelayedPlaybackUIView {
        let view = DelayedPlaybackUIView(compressedBuffer: compressedBuffer)
        return view
    }

    func updateUIView(_ uiView: DelayedPlaybackUIView, context: Context) {
        // Buffer reference is set at creation
    }

    static func dismantleUIView(_ uiView: DelayedPlaybackUIView, coordinator: ()) {
        uiView.stopRendering()
    }
}

/// UIView that renders delayed frames using UIImageView for maximum reliability.
/// Reads from the CompressedFrameBuffer, which decodes H.264 data on-the-fly.
class DelayedPlaybackUIView: UIView {
    private let imageView = UIImageView()
    private var displayLink: CADisplayLink?
    private let compressedBuffer: CompressedFrameBuffer
    private let ciContext = CIContext(options: [.useSoftwareRenderer: false])
    private var lastRenderedWriteCount: Int = -1

    init(compressedBuffer: CompressedFrameBuffer) {
        self.compressedBuffer = compressedBuffer
        super.init(frame: .zero)
        setupImageView()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupImageView() {
        imageView.contentMode = .scaleAspectFill
        imageView.clipsToBounds = true
        imageView.translatesAutoresizingMaskIntoConstraints = false
        addSubview(imageView)
        NSLayoutConstraint.activate([
            imageView.topAnchor.constraint(equalTo: topAnchor),
            imageView.bottomAnchor.constraint(equalTo: bottomAnchor),
            imageView.leadingAnchor.constraint(equalTo: leadingAnchor),
            imageView.trailingAnchor.constraint(equalTo: trailingAnchor),
        ])
    }

    override func didMoveToWindow() {
        super.didMoveToWindow()
        if window != nil {
            startDisplayLink()
        } else {
            stopRendering()
        }
    }

    // MARK: - Display Link

    private func startDisplayLink() {
        guard displayLink == nil else { return }
        displayLink = CADisplayLink(target: self, selector: #selector(renderFrame))
        displayLink?.add(to: .main, forMode: .common)
    }

    @objc private func renderFrame() {
        let currentWriteCount = compressedBuffer.totalFramesWritten
        guard currentWriteCount > 0, currentWriteCount != lastRenderedWriteCount else { return }

        // read() decodes the compressed H.264 data on-the-fly
        guard let (pixelBuffer, _) = compressedBuffer.read() else { return }
        lastRenderedWriteCount = currentWriteCount

        // Convert CVPixelBuffer -> CIImage -> CGImage -> UIImage
        let ciImage = CIImage(cvPixelBuffer: pixelBuffer)
        guard let cgImage = ciContext.createCGImage(ciImage, from: ciImage.extent) else { return }
        let uiImage = UIImage(cgImage: cgImage)

        imageView.image = uiImage
    }

    func stopRendering() {
        displayLink?.invalidate()
        displayLink = nil
    }
}
