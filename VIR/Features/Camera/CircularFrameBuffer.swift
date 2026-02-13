import Foundation
import CoreVideo
import os

/// Thread-safe circular (ring) buffer that holds CVPixelBuffers in RAM
/// for delayed video playback. The write head always leads the read head
/// by exactly `delayFrameCount` frames.
///
/// IMPORTANT: Pixel buffers from AVCaptureVideoDataOutput are pooled and reused
/// by AVFoundation. We must COPY each frame's data into our own buffers,
/// otherwise "old" frames get silently overwritten with new data.
final class CircularFrameBuffer: @unchecked Sendable {
    // MARK: - Properties

    private var buffer: [CVPixelBuffer?]
    private var timestamps: [TimeInterval]
    private(set) var capacity: Int
    private(set) var writeIndex: Int = 0
    private(set) var totalFramesWritten: Int = 0
    private let lock = NSLock()

    /// Our own pixel buffer pool for copying frames (avoids per-frame allocation overhead)
    private var pixelBufferPool: CVPixelBufferPool?

    /// Number of frames the read head trails behind the write head
    private(set) var delayFrameCount: Int

    /// Marked frame indices for key point clipping
    private(set) var markedIndices: [Int] = []

    // MARK: - Computed

    var readIndex: Int {
        guard totalFramesWritten > delayFrameCount else { return 0 }
        let rawRead = writeIndex - delayFrameCount
        return rawRead >= 0 ? rawRead : rawRead + capacity
    }

    var isFull: Bool {
        totalFramesWritten >= capacity
    }

    var fillLevel: Double {
        min(Double(totalFramesWritten) / Double(capacity), 1.0)
    }

    var hasEnoughFramesForDelay: Bool {
        totalFramesWritten >= delayFrameCount
    }

    // MARK: - Init

    /// Creates a circular frame buffer.
    /// - Parameters:
    ///   - capacity: Total number of frames the buffer can hold
    ///   - delayFrameCount: How many frames behind the read head trails
    init(capacity: Int, delayFrameCount: Int) {
        self.capacity = max(capacity, delayFrameCount + 1)
        self.delayFrameCount = delayFrameCount
        self.buffer = Array(repeating: nil, count: self.capacity)
        self.timestamps = Array(repeating: 0, count: self.capacity)
    }

    // MARK: - Write

    /// Writes a COPY of the pixel buffer to the ring buffer at the current write head,
    /// then advances. The copy is essential because AVFoundation recycles the original
    /// pixel buffers from the camera output.
    func write(_ pixelBuffer: CVPixelBuffer, timestamp: TimeInterval) {
        // Copy the pixel buffer data so we own it
        guard let copiedBuffer = copyPixelBuffer(pixelBuffer) else { return }

        lock.lock()
        buffer[writeIndex] = copiedBuffer
        timestamps[writeIndex] = timestamp
        writeIndex = (writeIndex + 1) % capacity
        totalFramesWritten += 1
        lock.unlock()
    }

    /// Deep-copies a CVPixelBuffer's pixel data into a new buffer we own.
    private func copyPixelBuffer(_ source: CVPixelBuffer) -> CVPixelBuffer? {
        let width = CVPixelBufferGetWidth(source)
        let height = CVPixelBufferGetHeight(source)
        let pixelFormat = CVPixelBufferGetPixelFormatType(source)

        // Create or reuse pool if dimensions match
        if pixelBufferPool == nil {
            let poolAttributes: [String: Any] = [
                kCVPixelBufferPoolMinimumBufferCountKey as String: capacity
            ]
            let pixelBufferAttributes: [String: Any] = [
                kCVPixelBufferPixelFormatTypeKey as String: pixelFormat,
                kCVPixelBufferWidthKey as String: width,
                kCVPixelBufferHeightKey as String: height,
                kCVPixelBufferIOSurfacePropertiesKey as String: [:]
            ]
            CVPixelBufferPoolCreate(
                kCFAllocatorDefault,
                poolAttributes as CFDictionary,
                pixelBufferAttributes as CFDictionary,
                &pixelBufferPool
            )
        }

        var destination: CVPixelBuffer?
        if let pool = pixelBufferPool {
            CVPixelBufferPoolCreatePixelBuffer(kCFAllocatorDefault, pool, &destination)
        }

        // Fallback: create without pool
        if destination == nil {
            CVPixelBufferCreate(
                kCFAllocatorDefault,
                width, height,
                pixelFormat,
                [kCVPixelBufferIOSurfacePropertiesKey: [:]] as CFDictionary,
                &destination
            )
        }

        guard let dest = destination else { return nil }

        CVPixelBufferLockBaseAddress(source, .readOnly)
        CVPixelBufferLockBaseAddress(dest, [])

        let srcPlanes = CVPixelBufferGetPlaneCount(source)
        if srcPlanes > 0 {
            // Planar format
            for plane in 0..<srcPlanes {
                guard let srcAddr = CVPixelBufferGetBaseAddressOfPlane(source, plane),
                      let dstAddr = CVPixelBufferGetBaseAddressOfPlane(dest, plane) else { continue }
                let srcBytesPerRow = CVPixelBufferGetBytesPerRowOfPlane(source, plane)
                let dstBytesPerRow = CVPixelBufferGetBytesPerRowOfPlane(dest, plane)
                let planeHeight = CVPixelBufferGetHeightOfPlane(source, plane)
                let copyBytes = min(srcBytesPerRow, dstBytesPerRow)
                for row in 0..<planeHeight {
                    memcpy(dstAddr + row * dstBytesPerRow,
                           srcAddr + row * srcBytesPerRow,
                           copyBytes)
                }
            }
        } else {
            // Non-planar (BGRA, etc.)
            guard let srcAddr = CVPixelBufferGetBaseAddress(source),
                  let dstAddr = CVPixelBufferGetBaseAddress(dest) else {
                CVPixelBufferUnlockBaseAddress(source, .readOnly)
                CVPixelBufferUnlockBaseAddress(dest, [])
                return nil
            }
            let srcBytesPerRow = CVPixelBufferGetBytesPerRow(source)
            let dstBytesPerRow = CVPixelBufferGetBytesPerRow(dest)
            let copyBytes = min(srcBytesPerRow, dstBytesPerRow)
            for row in 0..<height {
                memcpy(dstAddr + row * dstBytesPerRow,
                       srcAddr + row * srcBytesPerRow,
                       copyBytes)
            }
        }

        CVPixelBufferUnlockBaseAddress(dest, [])
        CVPixelBufferUnlockBaseAddress(source, .readOnly)

        return dest
    }

    // MARK: - Read

    /// Reads the frame at the current read head (delayed frame).
    /// Returns nil if not enough frames have been written yet.
    func read() -> (CVPixelBuffer, TimeInterval)? {
        lock.lock()
        defer { lock.unlock() }
        guard totalFramesWritten > delayFrameCount else { return nil }
        let idx = _readIndex()
        guard let frame = buffer[idx] else { return nil }
        return (frame, timestamps[idx])
    }

    private func _readIndex() -> Int {
        let rawRead = writeIndex - delayFrameCount
        return rawRead >= 0 ? rawRead : rawRead + capacity
    }

    // MARK: - Marking

    /// Marks the current READ position (delayed frame) as a key point.
    /// This is the frame the user is currently seeing on the delayed display.
    func markCurrentFrame() -> Int {
        lock.lock()
        let frameIdx = max(0, totalFramesWritten - delayFrameCount)
        markedIndices.append(frameIdx)
        lock.unlock()
        return frameIdx
    }

    // MARK: - Buffer Access (for clipping)

    /// Returns all buffered frames between two frame indices (inclusive).
    /// Used by AutoClipper after session stops.
    func frames(from startFrame: Int, to endFrame: Int) -> [(CVPixelBuffer, TimeInterval)] {
        lock.lock()
        defer { lock.unlock() }
        var result: [(CVPixelBuffer, TimeInterval)] = []
        for frameNum in startFrame...endFrame {
            let idx = frameNum % capacity
            if let frame = buffer[idx] {
                result.append((frame, timestamps[idx]))
            }
        }
        return result
    }

    // MARK: - Reset

    func reset() {
        lock.lock()
        for i in 0..<capacity {
            buffer[i] = nil
            timestamps[i] = 0
        }
        writeIndex = 0
        totalFramesWritten = 0
        markedIndices = []
        lock.unlock()
    }

    /// Updates the delay frame count (e.g., when user changes delay setting).
    func updateDelay(_ newDelayFrameCount: Int) {
        lock.lock()
        delayFrameCount = newDelayFrameCount
        lock.unlock()
    }

    // MARK: - Memory Estimation

    /// Estimates the maximum buffer capacity based on available device memory.
    /// Uses actual raw BGRA frame sizes for accurate estimation.
    static func estimateMaxCapacity(
        resolution: VideoResolution,
        fps: FrameRate,
        delaySeconds: Double
    ) -> (maxFrames: Int, maxDuration: TimeInterval) {
        let availableMemory = os_proc_available_memory()
        let usableMemory = Int(Double(availableMemory) * VIRConstants.memoryUsageFraction)

        // Raw BGRA frame size: width × height × 4 bytes per pixel
        let rawFrameSize = resolution.rawFrameSize

        let maxFrames = usableMemory / rawFrameSize
        let maxDuration = TimeInterval(maxFrames) / TimeInterval(fps.rawValue)

        return (maxFrames, maxDuration)
    }
}
