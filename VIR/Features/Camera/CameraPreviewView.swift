import SwiftUI
import AVFoundation

/// A live camera preview using AVCaptureVideoPreviewLayer.
/// This shows the real-time (non-delayed) camera feed.
struct CameraPreviewView: UIViewRepresentable {
    let session: AVCaptureSession

    func makeUIView(context: Context) -> CameraPreviewUIView {
        let view = CameraPreviewUIView()
        view.previewLayer.session = session
        view.previewLayer.videoGravity = .resizeAspectFill
        return view
    }

    func updateUIView(_ uiView: CameraPreviewUIView, context: Context) {
        uiView.previewLayer.session = session
    }
}

@MainActor
class CameraPreviewUIView: UIView {
    override class var layerClass: AnyClass {
        AVCaptureVideoPreviewLayer.self
    }

    var previewLayer: AVCaptureVideoPreviewLayer {
        layer as! AVCaptureVideoPreviewLayer
    }

    private var orientationObserver: NSObjectProtocol?

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupOrientationObserver()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupOrientationObserver()
    }

    deinit {
        // UIView deinit is always main-thread in iOS, safe to assume isolated
        MainActor.assumeIsolated {
            if let observer = orientationObserver {
                NotificationCenter.default.removeObserver(observer)
            }
        }
    }

    private func setupOrientationObserver() {
        // Apply initial orientation
        updateRotation()

        orientationObserver = NotificationCenter.default.addObserver(
            forName: UIDevice.orientationDidChangeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.updateRotation()
        }
    }

    private func updateRotation() {
        let orientation = UIDevice.current.orientation
        let angle: CGFloat

        // Determine if the active input is the front camera
        var isFront = false
        if let session = previewLayer.session,
           let input = session.inputs.first(where: { $0 is AVCaptureDeviceInput }) as? AVCaptureDeviceInput {
            isFront = input.device.position == .front
        }

        if isFront {
            switch orientation {
            case .portrait:           angle = 90  // Portrait is the same for front and back
            case .landscapeLeft:      angle = 180 // Landscape is mirrored
            case .landscapeRight:     angle = 0
            case .portraitUpsideDown: angle = 270
            default:                  return
            }
        } else {
            switch orientation {
            case .portrait:           angle = 90
            case .landscapeLeft:      angle = 0
            case .landscapeRight:     angle = 180
            case .portraitUpsideDown: angle = 270
            default:                  return
            }
        }

        if let connection = previewLayer.connection, connection.isVideoRotationAngleSupported(angle) {
            connection.videoRotationAngle = angle
        }
    }
}
