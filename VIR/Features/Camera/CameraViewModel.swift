import Foundation
import SwiftUI
import Combine
import os

/// ViewModel coordinating camera, compressed buffer, disk recorder, and marking state.
@Observable
@MainActor
class CameraViewModel {
    // MARK: - State

    var isRecording = false
    var bufferFillLevel: Double = 0
    var maxBufferDuration: TimeInterval = 0
    var elapsedTime: TimeInterval = 0
    var markCount: Int = 0
    var showMarkFlash: Bool = false
    var errorMessage: String?
    var permissionGranted = false
    var delayReady = false

    /// URL of the full recording file (available after stopping)
    var recordingFileURL: URL?

    /// Clips generated from the recording (populated during post-session)
    var savedClips: [Clip] = []

    // MARK: - Dependencies

    let cameraManager = CameraManager()
    private(set) var compressedBuffer: CompressedFrameBuffer?
    private var diskRecorder: DiskRecorder?
    private var startTime: Date?
    private var timerTask: Task<Void, Never>?
    private var permissionObserver: AnyCancellable?

    private var recordingFps: Int = 30
    private var recordingResolution: VideoResolution = .p720

    // MARK: - Setup

    func setup(settings: AppSettings) {
        cameraManager.requestPermission()

        // Sync initial permission state
        permissionGranted = cameraManager.permissionGranted

        // Calculate buffer capacity — only need enough for delay window
        let fps = settings.frameRate.rawValue
        let delayFrames = Int(settings.delaySeconds) * fps

        // Buffer capacity = delay frames + small margin (10% extra for smooth operation)
        let bufferCapacity = Int(Double(delayFrames) * 1.1) + fps  // +1 second margin

        // Estimate max possible delay for display
        let estimate = CompressedFrameBuffer.estimateMaxCapacity(
            resolution: settings.resolution,
            fps: settings.frameRate,
            delaySeconds: settings.delaySeconds
        )
        maxBufferDuration = estimate.maxDuration

        // Use portrait dimensions since camera output is rotated 90° to portrait
        compressedBuffer = CompressedFrameBuffer(
            capacity: bufferCapacity,
            delayFrameCount: delayFrames,
            width: settings.resolution.height,
            height: settings.resolution.width,
            fps: fps
        )

        cameraManager.compressedBuffer = compressedBuffer
        cameraManager.storeSettings(
            resolution: settings.resolution,
            frameRate: settings.frameRate,
            audioEnabled: settings.audioEnabled
        )

        // Store for clip writing
        recordingFps = fps
        recordingResolution = settings.resolution

        configureCamera(settings: settings)

        // Observe permission changes and start session when granted
        permissionObserver = cameraManager.$permissionGranted
            .receive(on: DispatchQueue.main)
            .sink { [weak self] granted in
                self?.permissionGranted = granted
                if granted {
                    self?.cameraManager.startSession()
                }
            }

        // If already granted, start immediately
        if cameraManager.permissionGranted {
            cameraManager.startSession()
        }
    }

    func configureCamera(settings: AppSettings) {
        // Reconfigure the camera session
        cameraManager.configureSession(
            resolution: settings.resolution,
            frameRate: settings.frameRate,
            cameraPosition: settings.cameraSelection,
            audioEnabled: settings.audioEnabled
        )

        // Recreate the compressed buffer with new FPS/resolution
        let fps = settings.frameRate.rawValue
        let delayFrames = Int(settings.delaySeconds) * fps
        let bufferCapacity = Int(Double(delayFrames) * 1.1) + fps

        // Use portrait dimensions (camera output rotated 90°)
        compressedBuffer = CompressedFrameBuffer(
            capacity: bufferCapacity,
            delayFrameCount: delayFrames,
            width: settings.resolution.height,
            height: settings.resolution.width,
            fps: fps
        )
        cameraManager.compressedBuffer = compressedBuffer
        delayReady = false

        // Update stored settings for recording
        recordingFps = fps
        recordingResolution = settings.resolution
        cameraManager.storeSettings(
            resolution: settings.resolution,
            frameRate: settings.frameRate,
            audioEnabled: settings.audioEnabled
        )
    }

    // MARK: - Recording Control

    func startRecording() {
        guard !isRecording else { return }
        isRecording = true
        delayReady = false
        startTime = Date()
        markCount = 0
        savedClips = []
        recordingFileURL = nil

        // Reset the compressed buffer for a fresh recording
        compressedBuffer?.reset()

        // Start disk recorder
        let recorder = DiskRecorder()
        do {
            // Use portrait dimensions (camera output is rotated 90°)
            try recorder.startRecording(
                width: recordingResolution.height,
                height: recordingResolution.width,
                fps: recordingFps
            )
            diskRecorder = recorder
            cameraManager.diskRecorder = recorder
        } catch {
            errorMessage = "Failed to start recording: \(error.localizedDescription)"
        }

        // Enable frame buffering
        cameraManager.isBuffering = true

        // Start the timer for elapsed time tracking.
        startTimer()
    }

    func stopRecording() async {
        guard isRecording else { return }
        isRecording = false
        cameraManager.isBuffering = false
        cameraManager.diskRecorder = nil
        stopTimer()

        // Stop disk recorder and wait for file to be finalized
        if let recorder = diskRecorder {
            let url = await recorder.stopRecording()
            self.recordingFileURL = url
        }
        diskRecorder = nil
    }

    // MARK: - Key Point Marking

    /// Marks the current delayed frame as a key point. Timestamps are recorded
    /// for later clip extraction from the saved recording file.
    func addMark(source: MarkSource, appState: AppState) {
        guard isRecording, let buffer = compressedBuffer else { return }

        let frameIndex = buffer.markCurrentFrame()
        // Use the delayed timestamp (what the user is seeing), not real-time
        let delaySeconds = Double(buffer.delayFrameCount) / Double(recordingFps)
        let timestamp = max(0, elapsedTime - delaySeconds)

        appState.addKeyPoint(
            frameIndex: frameIndex,
            timestamp: timestamp,
            source: source
        )

        markCount = appState.currentKeyPoints.count

        // Visual flash
        showMarkFlash = true
        DispatchQueue.main.asyncAfter(deadline: .now() + VIRConstants.markFlashDuration) { [weak self] in
            self?.showMarkFlash = false
        }

        // Haptic
        triggerHaptic()
    }

    // MARK: - Post-Session Clip Generation

    /// Generates clips from the saved recording file at key point timestamps.
    /// Called after stopping recording.
    func generateClips(keyPoints: [KeyPoint], sessionId: UUID) async {
        guard let fileURL = recordingFileURL, !keyPoints.isEmpty else {
            savedClips = []
            return
        }

        do {
            let result = try await AutoClipper.generateClips(
                from: fileURL,
                keyPoints: keyPoints,
                sessionId: sessionId,
                fps: recordingFps
            )
            await MainActor.run {
                self.savedClips = result.clips
            }
        } catch {
            await MainActor.run {
                self.errorMessage = "Failed to generate clips: \(error.localizedDescription)"
            }
        }
    }

    // MARK: - Haptic Feedback

    private func triggerHaptic() {
        let impact = UIImpactFeedbackGenerator(style: .heavy)
        impact.impactOccurred()
    }

    // MARK: - Timer

    private func startTimer() {
        stopTimer()
        timerTask = Task { [weak self] in
            while !Task.isCancelled {
                guard let self else { return }
                if let start = self.startTime {
                    self.elapsedTime = Date().timeIntervalSince(start)
                    self.bufferFillLevel = self.compressedBuffer?.fillLevel ?? 0
                    
                    // Update delay readiness so SwiftUI can react
                    if !self.delayReady, 
                       let buffer = self.compressedBuffer, 
                       buffer.hasEnoughFramesForDelay {
                        self.delayReady = true
                    }
                }
                try? await Task.sleep(for: .milliseconds(100))
            }
        }
    }

    private func stopTimer() {
        timerTask?.cancel()
        timerTask = nil
    }

    // MARK: - Cleanup

    func cleanup() {
        Task {
            await stopRecording()
        }
        cameraManager.stopSession()
        permissionObserver?.cancel()
        permissionObserver = nil
    }

    // MARK: - Update Settings

    func updateDelay(_ seconds: Double, fps: Int) {
        let newDelayFrames = Int(seconds) * fps
        compressedBuffer?.updateDelay(newDelayFrames)
    }
}
