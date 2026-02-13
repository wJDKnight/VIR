import Foundation
import AVFoundation
import CoreVideo
import UIKit

/// Manages the AVCaptureSession, configures camera input/output,
/// and feeds captured frames into both:
/// 1. CompressedFrameBuffer (for delayed playback in RAM)
/// 2. DiskRecorder (for saving the full recording to disk)
final class CameraManager: NSObject, ObservableObject, @unchecked Sendable {
    // MARK: - Published State

    @Published var isSessionRunning = false
    @Published var permissionGranted = false
    @Published var error: String?

    // Thread-safe recording state (accessed from both output queue and main actor)
    private let recordingLock = NSLock()
    private var _isBuffering = false
    var isBuffering: Bool {
        get { recordingLock.lock(); defer { recordingLock.unlock() }; return _isBuffering }
        set { recordingLock.lock(); _isBuffering = newValue; recordingLock.unlock() }
    }
    private var _diskRecorder: DiskRecorder?
    var diskRecorder: DiskRecorder? {
        get { recordingLock.lock(); defer { recordingLock.unlock() }; return _diskRecorder }
        set { recordingLock.lock(); _diskRecorder = newValue; recordingLock.unlock() }
    }

    // MARK: - AVFoundation

    let captureSession = AVCaptureSession()
    private var videoOutput = AVCaptureVideoDataOutput()
    private var currentDevice: AVCaptureDevice?
    private let sessionQueue = DispatchQueue(label: "com.vir.camera.session")
    private let outputQueue = DispatchQueue(label: "com.vir.camera.output")
    private var frameCount = 0

    // MARK: - Buffer & Recorder

    var compressedBuffer: CompressedFrameBuffer?
    private var sessionStartTime: Date?
    var onFrameWritten: (() -> Void)?

    // MARK: - Setup

    func requestPermission() {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            permissionGranted = true
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { [weak self] granted in
                DispatchQueue.main.async {
                    self?.permissionGranted = granted
                    if !granted {
                        self?.error = "Camera permission denied"
                    }
                }
            }
        default:
            permissionGranted = false
            error = "Camera permission denied. Please enable in Settings."
        }
    }

    func configureSession(
        resolution: VideoResolution,
        frameRate: FrameRate,
        cameraPosition: CameraSelection,
        audioEnabled: Bool
    ) {
        sessionQueue.async { [weak self] in
            self?._configureSession(
                resolution: resolution,
                frameRate: frameRate,
                cameraPosition: cameraPosition,
                audioEnabled: audioEnabled
            )
        }
    }

    private func _configureSession(
        resolution: VideoResolution,
        frameRate: FrameRate,
        cameraPosition: CameraSelection,
        audioEnabled: Bool
    ) {
        captureSession.beginConfiguration()
        defer { captureSession.commitConfiguration() }

        // Remove existing inputs
        captureSession.inputs.forEach { captureSession.removeInput($0) }
        captureSession.outputs.forEach { captureSession.removeOutput($0) }

        // Use .inputPriority so we can manually choose a format that
        // supports both the target resolution AND frame rate.
        // Session presets (e.g. .hd1280x720) lock the format and may
        // cap at 30 fps, which silently ignores a 60 fps setting.
        captureSession.sessionPreset = .inputPriority

        // Camera device
        let position: AVCaptureDevice.Position = cameraPosition == .front ? .front : .back
        guard let device = AVCaptureDevice.default(
            .builtInWideAngleCamera,
            for: .video,
            position: position
        ) else {
            DispatchQueue.main.async { [weak self] in self?.error = "Camera not available" }
            return
        }
        currentDevice = device

        // Find the best format matching target resolution AND frame rate
        let targetFPS = frameRate.rawValue
        let targetWidth = resolution.width
        let targetHeight = resolution.height

        do {
            try device.lockForConfiguration()

            // Pick a format that supports the target fps and has matching dimensions
            let bestFormat = device.formats.first { format in
                let desc = format.formatDescription
                let dims = CMVideoFormatDescriptionGetDimensions(desc)
                let matchesRes = Int(dims.width) == targetWidth && Int(dims.height) == targetHeight
                let supportsFPS = format.videoSupportedFrameRateRanges.contains {
                    $0.maxFrameRate >= Double(targetFPS)
                }
                return matchesRes && supportsFPS
            }

            // Fallback: any format that supports the fps
            let fallbackFormat = device.formats.first { format in
                format.videoSupportedFrameRateRanges.contains {
                    $0.maxFrameRate >= Double(targetFPS)
                }
            }

            if let format = bestFormat ?? fallbackFormat {
                device.activeFormat = format
                print("VIR Info: Selected format: \(format.formatDescription) for \(targetWidth)x\(targetHeight)@\(targetFPS)fps")
            }

            device.activeVideoMinFrameDuration = CMTime(value: 1, timescale: CMTimeScale(targetFPS))
            device.activeVideoMaxFrameDuration = CMTime(value: 1, timescale: CMTimeScale(targetFPS))
            device.unlockForConfiguration()
        } catch {
            DispatchQueue.main.async { [weak self] in self?.error = "Failed to configure frame rate" }
        }

        // Add video input
        guard let input = try? AVCaptureDeviceInput(device: device),
              captureSession.canAddInput(input) else {
            DispatchQueue.main.async { [weak self] in self?.error = "Cannot add camera input" }
            return
        }
        captureSession.addInput(input)

        // Add video output — use BGRA for compatibility with both compressed buffer and disk recorder
        videoOutput = AVCaptureVideoDataOutput()
        videoOutput.videoSettings = [
            kCVPixelBufferPixelFormatTypeKey as String: Int(kCVPixelFormatType_32BGRA)
        ]
        videoOutput.alwaysDiscardsLateVideoFrames = true
        videoOutput.setSampleBufferDelegate(self, queue: outputQueue)

        guard captureSession.canAddOutput(videoOutput) else {
            DispatchQueue.main.async { [weak self] in self?.error = "Cannot add video output" }
            return
        }
        captureSession.addOutput(videoOutput)

        // Fix video orientation
        if let connection = videoOutput.connection(with: .video) {
            if connection.isVideoRotationAngleSupported(90) {
                connection.videoRotationAngle = 90
            }
            if cameraPosition == .front && connection.isVideoMirroringSupported {
                connection.isVideoMirrored = true
            }
        }
    }

    // MARK: - Start / Stop

    func startSession() {
        sessionQueue.async { [weak self] in
            guard let self, !self.captureSession.isRunning else { return }
            self.captureSession.startRunning()
            self.sessionStartTime = Date()
            DispatchQueue.main.async { [weak self] in
                self?.isSessionRunning = true
            }
        }
    }

    func stopSession() {
        sessionQueue.async { [weak self] in
            guard let self, self.captureSession.isRunning else { return }
            self.captureSession.stopRunning()
            DispatchQueue.main.async { [weak self] in
                self?.isSessionRunning = false
            }
        }
    }

    // MARK: - Camera Switching

    func switchCamera(to position: CameraSelection) {
        guard let settings = currentSettings else { return }
        configureSession(
            resolution: settings.resolution,
            frameRate: settings.frameRate,
            cameraPosition: position,
            audioEnabled: settings.audioEnabled
        )
    }

    private var currentSettings: (resolution: VideoResolution, frameRate: FrameRate, audioEnabled: Bool)?

    func storeSettings(resolution: VideoResolution, frameRate: FrameRate, audioEnabled: Bool) {
        currentSettings = (resolution, frameRate, audioEnabled)
    }
}

// MARK: - AVCaptureVideoDataOutputSampleBufferDelegate

extension CameraManager: AVCaptureVideoDataOutputSampleBufferDelegate {
    nonisolated func captureOutput(
        _ output: AVCaptureOutput,
        didOutput sampleBuffer: CMSampleBuffer,
        from connection: AVCaptureConnection
    ) {
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
        let pts = CMSampleBufferGetPresentationTimeStamp(sampleBuffer)
        let timestamp = pts.seconds

        // Check buffering state (thread-safe via lock)
        guard isBuffering else { return }

        // 1. Feed disk recorder DIRECTLY on the output queue.
        //    The pixel buffer is only valid in this callback scope —
        //    AVFoundation recycles it once we return.
        diskRecorder?.appendPixelBuffer(pixelBuffer, presentationTime: pts)

        // 2. Feed compressed buffer (also on output queue — CompressedFrameBuffer is thread-safe)
        compressedBuffer?.write(pixelBuffer, timestamp: timestamp)

        // 3. Track frame count and notify (dispatch lightweight UI updates to main)
        frameCount += 1
        let count = frameCount
        if count % 100 == 0 {
            print("VIR Info: CameraManager captured frame \(count) at \(timestamp)")
        }
        let callback = onFrameWritten
        if callback != nil {
            Task { @MainActor in
                callback?()
            }
        }
    }

    nonisolated func captureOutput(
        _ output: AVCaptureOutput,
        didDrop sampleBuffer: CMSampleBuffer,
        from connection: AVCaptureConnection
    ) {
        // Frame dropped
    }
}
