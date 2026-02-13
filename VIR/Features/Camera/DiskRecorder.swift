import Foundation
import AVFoundation
import CoreVideo
import os

/// Continuously writes camera frames to a compressed H.264 .mp4 file on disk
/// using AVAssetWriter. This runs for the entire recording session, producing
/// a single file containing the full recording.
///
/// The saved file serves two purposes:
/// 1. The user can keep it as the full session recording
/// 2. Clips are extracted from it by trimming at key point timestamps
final class DiskRecorder: @unchecked Sendable {
    // MARK: - State

    enum State {
        case idle
        case recording
        case finished
        case failed(Error)
    }

    private(set) var state: State = .idle
    private(set) var outputURL: URL?

    // MARK: - AVAssetWriter

    private var assetWriter: AVAssetWriter?
    private var videoInput: AVAssetWriterInput?
    private var pixelBufferAdaptor: AVAssetWriterInputPixelBufferAdaptor?
    private var audioInput: AVAssetWriterInput?

    private var isStarted = false
    private var sessionStartTime: CMTime = .zero
    private let writerQueue = DispatchQueue(label: "com.vir.disk.recorder")

    // MARK: - Start

    /// Starts recording to a new file.
    /// - Parameters:
    ///   - width: Video width
    ///   - height: Video height
    ///   - fps: Target frame rate
    ///   - audioEnabled: Whether to include audio track (future use)
    func startRecording(width: Int, height: Int, fps: Int, audioEnabled: Bool = false) throws {
        let fileName = "recording_\(UUID().uuidString.prefix(8)).mp4"
        let url = VIRConstants.recordingsDirectory.appendingPathComponent(fileName)

        // Remove if exists
        try? FileManager.default.removeItem(at: url)

        let writer = try AVAssetWriter(outputURL: url, fileType: .mp4)

        // Video settings — H.264 with reasonable bitrate
        let videoSettings: [String: Any] = [
            AVVideoCodecKey: AVVideoCodecType.h264,
            AVVideoWidthKey: width,
            AVVideoHeightKey: height,
            AVVideoCompressionPropertiesKey: [
                AVVideoAverageBitRateKey: bitrate(for: width, height: height, fps: fps),
                AVVideoExpectedSourceFrameRateKey: fps,
                AVVideoProfileLevelKey: AVVideoProfileLevelH264MainAutoLevel,
                AVVideoMaxKeyFrameIntervalKey: fps  // 1 keyframe per second for easy seeking
            ]
        ]

        let input = AVAssetWriterInput(mediaType: .video, outputSettings: videoSettings)
        input.expectsMediaDataInRealTime = true

        let adaptor = AVAssetWriterInputPixelBufferAdaptor(
            assetWriterInput: input,
            sourcePixelBufferAttributes: [
                kCVPixelBufferPixelFormatTypeKey as String: Int(kCVPixelFormatType_32BGRA),
                kCVPixelBufferWidthKey as String: width,
                kCVPixelBufferHeightKey as String: height
            ]
        )

        guard writer.canAdd(input) else {
            throw DiskRecorderError.cannotAddInput
        }
        writer.add(input)

        self.assetWriter = writer
        self.videoInput = input
        self.pixelBufferAdaptor = adaptor
        self.outputURL = url
        self.isStarted = false

        writer.startWriting()
        print("VIR Info: DiskRecorder started writing to \(url)")
        state = .recording

        os_log(.info, "DiskRecorder: started recording to %{public}@", url.lastPathComponent)
    }

    // MARK: - Append Frame

    /// Appends a pixel buffer at the given presentation time.
    /// Must be called from a consistent queue (the camera output queue).
    func appendPixelBuffer(_ pixelBuffer: CVPixelBuffer, presentationTime: CMTime) {
        guard case .recording = state else { return }
        guard let writer = assetWriter, let input = videoInput, let adaptor = pixelBufferAdaptor else { return }

        // Start the session on the first frame
        if !isStarted {
            writer.startSession(atSourceTime: presentationTime)
            sessionStartTime = presentationTime
            isStarted = true
        }

        // Only append if the input is ready
        guard input.isReadyForMoreMediaData else {
            if writer.status == .failed {
                print("VIR Error: DiskRecorder writer failed: \(writer.error?.localizedDescription ?? "unknown")")
            } else {
                 // Trace dropped frames (throttling log?)
                // print("VIR Warning: DiskRecorder input not ready")
            }
            return
        }

        if adaptor.append(pixelBuffer, withPresentationTime: presentationTime) {
             // Success
        } else {
             print("VIR Error: DiskRecorder failed to append pixel buffer: \(writer.error?.localizedDescription ?? "unknown")")
        }
    }

    // MARK: - Stop

    /// Stops recording and finalizes the file.
    /// Returns the URL of the saved recording.
    func stopRecording() async -> URL? {
        guard case .recording = state else { return outputURL }
        guard let writer = assetWriter, let input = videoInput else { return nil }

        input.markAsFinished()

        // Wrap writer to silence Sendable warning (AVAssetWriter is thread-safe for finishWriting)
        struct UncheckedWriter: @unchecked Sendable { let writer: AVAssetWriter }
        let unchecked = UncheckedWriter(writer: writer)
        
        return await withCheckedContinuation { continuation in
            unchecked.writer.finishWriting { [weak self] in
                if unchecked.writer.status == .completed {
                    self?.state = .finished
                    let fileSize = (try? FileManager.default.attributesOfItem(atPath: unchecked.writer.outputURL.path)[.size] as? Int) ?? 0
                    print("VIR Info: DiskRecorder finished writing successfully, file size: \(fileSize) bytes")
                    continuation.resume(returning: self?.outputURL)
                } else {
                    self?.state = .failed(unchecked.writer.error ?? DiskRecorderError.writeFailed)
                    print("VIR Error: DiskRecorder finishWriting failed: \(unchecked.writer.error?.localizedDescription ?? "unknown")")
                    continuation.resume(returning: nil)
                }
            }
        }
    }

    // MARK: - Helpers

    /// Calculate a reasonable bitrate based on resolution and fps.
    private func bitrate(for width: Int, height: Int, fps: Int) -> Int {
        let pixels = width * height
        // Rough heuristic: ~3 bits per pixel at 30fps, scale with fps
        let baseBitrate = Double(pixels) * 3.0
        let fpsMultiplier = Double(fps) / 30.0
        let bitrate = Int(baseBitrate * fpsMultiplier)
        // Clamp between 1 Mbps and 20 Mbps
        return max(1_000_000, min(bitrate, 20_000_000))
    }

    /// Returns the duration of the recording so far.
    var recordingDuration: TimeInterval {
        guard isStarted else { return 0 }
        return 0 // Duration tracked externally via elapsed time
    }
}

// MARK: - Errors

enum DiskRecorderError: LocalizedError {
    case cannotAddInput
    case writeFailed

    var errorDescription: String? {
        switch self {
        case .cannotAddInput:
            return "Cannot add video input to asset writer"
        case .writeFailed:
            return "Failed to write recording to disk"
        }
    }
}
