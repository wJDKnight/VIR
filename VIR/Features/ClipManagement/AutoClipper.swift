import Foundation
import AVFoundation
import os

/// Splits a recorded video file into clips at key point marker timestamps
/// using AVAssetExportSession. This is much more memory-efficient than the
/// previous approach of extracting raw pixel buffers from a RAM buffer.
class AutoClipper {
    /// Result of clipping operation
    struct ClipResult {
        let clips: [Clip]
        let fileURLs: [URL]
    }

    /// Generates clips by trimming the recorded video file at key point timestamps.
    ///
    /// Clipping logic:
    /// - N markers produce N clips
    /// - Clip 1: from recording start → marker 1's timestamp
    /// - Clip 2: from marker 1's timestamp → marker 2's timestamp
    /// - Clip N: from marker (N-1)'s timestamp → marker N's timestamp
    static func generateClips(
        from recordingURL: URL,
        keyPoints: [KeyPoint],
        sessionId: UUID,
        sessionStartTime: Date,
        fps: Int
    ) async throws -> ClipResult {
        let sortedMarks = keyPoints.sorted { $0.timestamp < $1.timestamp }

        guard !sortedMarks.isEmpty else {
            return ClipResult(clips: [], fileURLs: [])
        }

        let asset = AVURLAsset(url: recordingURL)
        let duration = try await asset.load(.duration)

        var clips: [Clip] = []
        var fileURLs: [URL] = []

        // Date formatter for filename
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd_HHmmss"
        let dateString = formatter.string(from: sessionStartTime)

        for (index, mark) in sortedMarks.enumerated() {
            let clipStartTime: TimeInterval
            if index == 0 {
                clipStartTime = 0
            } else {
                clipStartTime = sortedMarks[index - 1].timestamp
            }
            let clipEndTime = mark.timestamp

            guard clipStartTime < clipEndTime else { continue }

            // Clamp to actual recording duration
            let clampedEnd = min(clipEndTime, duration.seconds)
            guard clipStartTime < clampedEnd else { continue }

            // Generate output file URL
            // Format: yyyyMMdd_HHmmss_01.mp4 (1-based index)
            let orderNumber = String(format: "%02d", index + 1)
            let fileName = "\(dateString)_\(orderNumber).mp4"
            let fileURL = VIRConstants.clipsDirectory.appendingPathComponent(fileName)
            try? FileManager.default.removeItem(at: fileURL)

            // Trim the source video to this time range
            let startCMTime = CMTime(seconds: clipStartTime, preferredTimescale: 600)
            let endCMTime = CMTime(seconds: clampedEnd, preferredTimescale: 600)
            let timeRange = CMTimeRange(start: startCMTime, end: endCMTime)

            try await exportClip(
                from: asset,
                timeRange: timeRange,
                to: fileURL
            )

            fileURLs.append(fileURL)
            
            // Get file size
            let resources = try? fileURL.resourceValues(forKeys: [.fileSizeKey])
            let fileSize = Int64(resources?.fileSize ?? 0)

            let clip = Clip(
                sessionId: sessionId,
                startTime: clipStartTime,
                endTime: clampedEnd,
                fileName: fileName,
                fileSize: fileSize
            )
            clips.append(clip)

            os_log(.info, "AutoClipper: generated clip %d (%.1fs - %.1fs)", index, clipStartTime, clampedEnd)
        }

        return ClipResult(clips: clips, fileURLs: fileURLs)
    }

    /// Exports (trims) a portion of a video asset to a new file.
    /// Uses passthrough codec (no re-encoding) for speed and quality.
    private static func exportClip(
        from asset: AVAsset,
        timeRange: CMTimeRange,
        to outputURL: URL
    ) async throws {
        guard let exportSession = AVAssetExportSession(
            asset: asset,
            presetName: AVAssetExportPresetPassthrough
        ) else {
            throw AutoClipperError.exportSessionFailed
        }

        exportSession.timeRange = timeRange
        try await exportSession.export(to: outputURL, as: .mp4)
    }
}

// MARK: - Errors

enum AutoClipperError: LocalizedError {
    case exportSessionFailed
    case exportFailed
    case exportCancelled

    var errorDescription: String? {
        switch self {
        case .exportSessionFailed:
            return "Failed to create export session"
        case .exportFailed:
            return "Failed to export clip"
        case .exportCancelled:
            return "Clip export was cancelled"
        }
    }
}
