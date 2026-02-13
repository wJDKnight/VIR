import Foundation
import CoreVideo
import VideoToolbox
import os

/// Thread-safe circular buffer that stores **H.264 compressed** frame data in RAM.
///
/// Write path: raw CVPixelBuffer → VTCompressionSession (hardware H.264) → Data blob stored in ring
/// Read path:  Data blob from ring → VTDecompressionSession (hardware decode) → CVPixelBuffer for display
///
/// At 1080p/60fps, each compressed frame is ~10–50 KB (vs. ~8.3 MB raw BGRA),
/// so a 60-second delay buffer uses ~36–180 MB instead of ~30 GB.
final class CompressedFrameBuffer: @unchecked Sendable {
    // MARK: - Types

    private struct CompressedFrame {
        let data: Data
        let timestamp: TimeInterval
        let isKeyFrame: Bool
    }

    // MARK: - Properties

    private var buffer: [CompressedFrame?]
    private(set) var capacity: Int
    private(set) var writeIndex: Int = 0
    private(set) var totalFramesWritten: Int = 0
    private let lock = NSLock()

    /// Number of frames the read head trails behind the write head
    private(set) var delayFrameCount: Int

    /// Tracks the last buffer index we decoded, so we never skip frames
    /// and break the H.264 decoder's reference frame chain.
    private var lastDecodedBufferIndex: Int = -1

    /// Marked frame indices for key point clipping
    private(set) var markedIndices: [Int] = []

    // MARK: - VideoToolbox Compression

    private var compressionSession: VTCompressionSession?
    private var decompressionSession: VTDecompressionSession?
    private var formatDescription: CMFormatDescription?
    private let width: Int32
    private let height: Int32

    /// Timestamp for the frame currently being encoded (set before encode, read in callback)
    private var pendingTimestamp: TimeInterval = 0

    /// Latest decoded frame from decompression
    fileprivate var decodedFrame: CVPixelBuffer?
    private let decodeSemaphore = DispatchSemaphore(value: 0)

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

    /// Creates a compressed frame buffer.
    /// - Parameters:
    ///   - capacity: Total number of compressed frames the buffer can hold
    ///   - delayFrameCount: How many frames behind the read head trails
    ///   - width: Video width in pixels
    ///   - height: Video height in pixels
    ///   - fps: Frames per second (used for encoder configuration)
    init(capacity: Int, delayFrameCount: Int, width: Int, height: Int, fps: Int) {
        self.capacity = max(capacity, delayFrameCount + 1)
        self.delayFrameCount = delayFrameCount
        self.width = Int32(width)
        self.height = Int32(height)
        self.buffer = Array(repeating: nil, count: self.capacity)

        setupCompression(fps: fps)
    }

    deinit {
        teardownCompression()
    }

    // MARK: - Compression Setup

    private func setupCompression(fps: Int) {
        // --- Encoder ---
        // Allow software compression fallback (essential for Simulator)
        let encoderSpec: [String: Any] = [:]

        var session: VTCompressionSession?
        let status = VTCompressionSessionCreate(
            allocator: kCFAllocatorDefault,
            width: width,
            height: height,
            codecType: kCMVideoCodecType_H264,
            encoderSpecification: encoderSpec as CFDictionary,
            imageBufferAttributes: nil,
            compressedDataAllocator: nil,
            outputCallback: nil,
            refcon: nil,
            compressionSessionOut: &session
        )

        guard status == noErr, let session = session else {
            os_log(.error, "Failed to create VTCompressionSession: %d", status)
            return
        }

        compressionSession = session

        // Configure for low-latency real-time encoding
        VTSessionSetProperty(session, key: kVTCompressionPropertyKey_RealTime, value: kCFBooleanTrue)
        // High profile: enables 8×8 DCT transforms and CABAC entropy coding,
        // significantly improving quality on motion-heavy frames at the same bitrate.
        VTSessionSetProperty(session, key: kVTCompressionPropertyKey_ProfileLevel,
                             value: kVTProfileLevel_H264_High_AutoLevel)
        VTSessionSetProperty(session, key: kVTCompressionPropertyKey_AllowFrameReordering,
                             value: kCFBooleanFalse)
        // Key frame every 1 second (by frame count and by duration)
        VTSessionSetProperty(session, key: kVTCompressionPropertyKey_MaxKeyFrameInterval,
                             value: fps as CFNumber)
        VTSessionSetProperty(session, key: kVTCompressionPropertyKey_MaxKeyFrameIntervalDuration,
                             value: 1.0 as CFNumber)
        // Tell the encoder the expected frame rate for better temporal prediction
        VTSessionSetProperty(session, key: kVTCompressionPropertyKey_ExpectedFrameRate,
                             value: fps as CFNumber)

        // Target bitrate: scale with resolution for good quality delayed preview
        let pixels = Int(width) * Int(height)
        let bitrate: Int
        if pixels >= 1920 * 1080 {
            bitrate = 15_000_000  // 15 Mbps for 1080p
        } else if pixels >= 1280 * 720 {
            bitrate = 10_000_000  // 10 Mbps for 720p
        } else {
            bitrate = 8_000_000   //  8 Mbps for lower
        }
        VTSessionSetProperty(session, key: kVTCompressionPropertyKey_AverageBitRate,
                             value: bitrate as CFNumber)
        // Peak bitrate: 1.5× average over a 1-second window.
        // Prevents the VBR encoder from starving motion-heavy frames
        // (the main cause of pixelation on moving objects).
        let peakBytesPerSecond = bitrate * 3 / 2 / 8  // bytes
        let dataRateLimits: [Int] = [peakBytesPerSecond, 1]
        VTSessionSetProperty(session, key: kVTCompressionPropertyKey_DataRateLimits,
                             value: dataRateLimits as CFArray)
        // Quality hint — keeps a floor during high-motion sequences
        VTSessionSetProperty(session, key: kVTCompressionPropertyKey_Quality,
                             value: 0.85 as CFNumber)

        VTCompressionSessionPrepareToEncodeFrames(session)
    }

    private func setupDecompression(formatDesc: CMFormatDescription) {
        formatDescription = formatDesc

        // Allow software decompression fallback
        let decoderSpec: [String: Any] = [:]

        let destAttributes: [String: Any] = [
            kCVPixelBufferPixelFormatTypeKey as String: Int(kCVPixelFormatType_32BGRA),
            kCVPixelBufferWidthKey as String: Int(width),
            kCVPixelBufferHeightKey as String: Int(height),
            kCVPixelBufferIOSurfacePropertiesKey as String: [:] as [String: Any]
        ]

        var session: VTDecompressionSession?
        let status = VTDecompressionSessionCreate(
            allocator: kCFAllocatorDefault,
            formatDescription: formatDesc,
            decoderSpecification: decoderSpec as CFDictionary,
            imageBufferAttributes: destAttributes as CFDictionary,
            outputCallback: nil,
            decompressionSessionOut: &session
        )

        guard status == noErr, let session = session else {
            os_log(.error, "Failed to create VTDecompressionSession: %d", status)
            return
        }

        decompressionSession = session
    }

    private func teardownCompression() {
        if let session = compressionSession {
            VTCompressionSessionCompleteFrames(session, untilPresentationTimeStamp: .invalid)
            VTCompressionSessionInvalidate(session)
            compressionSession = nil
        }
        if let session = decompressionSession {
            VTDecompressionSessionInvalidate(session)
            decompressionSession = nil
        }
    }

    // MARK: - Write (Encode + Store)

    /// Encodes the raw pixel buffer via hardware H.264. The encoder callback
    /// writes the compressed data directly into the ring buffer asynchronously.
    /// This does NOT block the camera output queue.
    func write(_ pixelBuffer: CVPixelBuffer, timestamp: TimeInterval) {
        guard let session = compressionSession else {
            print("VIR Error: compressionSession is nil")
            return
        }

        let pts = CMTime(seconds: timestamp, preferredTimescale: 90000)
        let duration = CMTime.invalid
        var infoFlags = VTEncodeInfoFlags()

        // Capture timestamp for use in the async callback
        let capturedTimestamp = timestamp

        let status = VTCompressionSessionEncodeFrame(
            session,
            imageBuffer: pixelBuffer,
            presentationTimeStamp: pts,
            duration: duration,
            frameProperties: nil,
            infoFlagsOut: &infoFlags
        ) { [weak self] encodeStatus, _, encodedSampleBuffer in
            guard encodeStatus == noErr, let encodedSampleBuffer = encodedSampleBuffer else {
                if encodeStatus != noErr {
                    print("VIR Error: Encode failed with status \(encodeStatus)")
                }
                return
            }
            self?.handleEncodedFrame(encodedSampleBuffer, timestamp: capturedTimestamp)
        }

        if status != noErr {
            print("VIR Error: VTCompressionSessionEncodeFrame returned \(status)")
        }
    }

    /// Called by the encoder output handler. Writes directly to the ring buffer.
    private func handleEncodedFrame(_ sampleBuffer: CMSampleBuffer, timestamp: TimeInterval) {
        // Check if it's a key frame
        let attachments = CMSampleBufferGetSampleAttachmentsArray(sampleBuffer, createIfNecessary: false)
        var isKey = true
        if let attachments = attachments, CFArrayGetCount(attachments) > 0 {
            let dict = unsafeBitCast(CFArrayGetValueAtIndex(attachments, 0), to: CFDictionary.self)
            let notSync = CFDictionaryGetValue(dict,
                Unmanaged.passUnretained(kCMSampleAttachmentKey_NotSync).toOpaque())
            if notSync != nil {
                isKey = false
            }
        }

        // Extract format description (needed to set up decoder on first key frame)
        if isKey, formatDescription == nil {
            if let fd = CMSampleBufferGetFormatDescription(sampleBuffer) {
                setupDecompression(formatDesc: fd)
            }
        }

        // If it's a key frame, update the stored format description
        if isKey, let fd = CMSampleBufferGetFormatDescription(sampleBuffer) {
            formatDescription = fd
        }

        // Get the compressed data
        guard let dataBuffer = CMSampleBufferGetDataBuffer(sampleBuffer) else { return }
        var totalLength: Int = 0
        var dataPointer: UnsafeMutablePointer<Int8>?
        CMBlockBufferGetDataPointer(dataBuffer, atOffset: 0, lengthAtOffsetOut: nil,
                                    totalLengthOut: &totalLength, dataPointerOut: &dataPointer)
        guard let pointer = dataPointer, totalLength > 0 else { return }

        var data = Data(bytes: pointer, count: totalLength)

        // For key frames, prepend the format description (SPS/PPS) so the decoder
        // can be recreated at any key frame in the ring buffer
        if isKey, let fd = CMSampleBufferGetFormatDescription(sampleBuffer) {
            if let paramData = extractParameterSets(from: fd) {
                var paramLen = UInt32(paramData.count).bigEndian
                var combined = Data(bytes: &paramLen, count: 4)
                combined.append(paramData)
                combined.append(data)
                data = combined
            }
        }

        // Write directly to ring buffer (thread-safe)
        let frame = CompressedFrame(data: data, timestamp: timestamp, isKeyFrame: isKey)
        lock.lock()
        buffer[writeIndex] = frame
        writeIndex = (writeIndex + 1) % capacity
        totalFramesWritten += 1
        if totalFramesWritten % 100 == 0 {
            print("VIR Info: Buffered \(totalFramesWritten) frames. WriteIdx: \(writeIndex). Fill: \(fillLevel)")
        }
        lock.unlock()
    }

    /// Extract SPS and PPS parameter sets from a format description.
    private func extractParameterSets(from formatDesc: CMFormatDescription) -> Data? {
        var paramSetCount: Int = 0
        CMVideoFormatDescriptionGetH264ParameterSetAtIndex(
            formatDesc, parameterSetIndex: 0,
            parameterSetPointerOut: nil, parameterSetSizeOut: nil,
            parameterSetCountOut: &paramSetCount, nalUnitHeaderLengthOut: nil
        )

        var data = Data()
        for i in 0..<paramSetCount {
            var paramSetPointer: UnsafePointer<UInt8>?
            var paramSetSize: Int = 0
            let status = CMVideoFormatDescriptionGetH264ParameterSetAtIndex(
                formatDesc, parameterSetIndex: i,
                parameterSetPointerOut: &paramSetPointer, parameterSetSizeOut: &paramSetSize,
                parameterSetCountOut: nil, nalUnitHeaderLengthOut: nil
            )
            guard status == noErr, let pointer = paramSetPointer else { continue }
            // Write NAL start code + parameter set
            let startCode: [UInt8] = [0x00, 0x00, 0x00, 0x01]
            data.append(contentsOf: startCode)
            data.append(pointer, count: paramSetSize)
        }
        return data.isEmpty ? nil : data
    }

    // MARK: - Read (Decode + Return)

    /// Reads and decodes the frame at the current read head (delayed frame).
    ///
    /// **Critical**: The H.264 decoder relies on seeing every frame in sequence
    /// to maintain correct reference frames for motion prediction.  If the
    /// display-link skips a tick, the read index can jump by 2+.  We therefore
    /// decode ALL intermediate frames (discarding their pixel output) so the
    /// decoder's internal reference state stays valid.
    func read() -> (CVPixelBuffer, TimeInterval)? {
        lock.lock()
        guard totalFramesWritten > delayFrameCount else {
            lock.unlock()
            return nil
        }
        let targetIdx = _readIndex()

        // On first read, seed lastDecodedBufferIndex just before the target
        if lastDecodedBufferIndex < 0 {
            lastDecodedBufferIndex = targetIdx
        }

        // Collect every frame from (lastDecoded+1) … targetIdx that we haven't
        // decoded yet.  We must hold the lock only while copying lightweight
        // frame metadata; decoding happens outside the lock.
        var framesToDecode: [(idx: Int, data: Data, ts: TimeInterval, isKey: Bool)] = []

        var cursor = lastDecodedBufferIndex
        while cursor != targetIdx {
            cursor = (cursor + 1) % capacity
            if let frame = buffer[cursor] {
                framesToDecode.append((cursor, frame.data, frame.timestamp, frame.isKeyFrame))
            }
        }
        lock.unlock()

        // Decode all intermediate frames sequentially to keep the decoder's
        // reference frame chain intact.  Only the LAST decoded frame is returned.
        var lastDecoded: CVPixelBuffer?
        var lastTimestamp: TimeInterval = 0
        for entry in framesToDecode {
            if let pb = decodeFrame(data: entry.data, timestamp: entry.ts, isKeyFrame: entry.isKey) {
                lastDecoded = pb
                lastTimestamp = entry.ts
            }
        }

        lock.lock()
        lastDecodedBufferIndex = targetIdx
        lock.unlock()

        guard let decoded = lastDecoded else { return nil }
        return (decoded, lastTimestamp)
    }

    private func _readIndex() -> Int {
        let rawRead = writeIndex - delayFrameCount
        return rawRead >= 0 ? rawRead : rawRead + capacity
    }

    /// Decodes a single compressed frame using VTDecompressionSession.
    private func decodeFrame(data: Data, timestamp: TimeInterval, isKeyFrame: Bool) -> CVPixelBuffer? {
        var frameData = data

        // For key frames, extract parameter sets and recreate format description
        if isKeyFrame && data.count > 4 {
            let paramLen = data.withUnsafeBytes { ptr -> UInt32 in
                ptr.load(as: UInt32.self).bigEndian
            }
            let paramEnd = 4 + Int(paramLen)
            if paramEnd < data.count {
                let paramData = data[4..<paramEnd]
                frameData = data[paramEnd...]  // actual compressed data

                // Recreate format description from parameter sets
                if let fd = createFormatDescription(from: Data(paramData)) {
                    if formatDescription == nil || isKey(fd, differentFrom: formatDescription!) {
                        formatDescription = fd
                        // Recreate decoder with new format
                        if let session = decompressionSession {
                            VTDecompressionSessionInvalidate(session)
                            decompressionSession = nil
                        }
                        setupDecompression(formatDesc: fd)
                    }
                }
            }
        }

        guard let session = decompressionSession, let formatDesc = formatDescription else {
            return nil
        }

        // Create a CMBlockBuffer that OWNS a copy of the data.
        // Previously we wrapped the pointer from `withUnsafeBytes` with
        // kCFAllocatorNull, but that pointer is only valid inside the closure.
        // Using it outside caused the decoder to read stale/moved memory,
        // producing block artifacts on motion-heavy frames.
        var blockBuffer: CMBlockBuffer?
        var createStatus = CMBlockBufferCreateWithMemoryBlock(
            allocator: kCFAllocatorDefault,
            memoryBlock: nil,           // nil → allocate a new buffer
            blockLength: frameData.count,
            blockAllocator: nil,
            customBlockSource: nil,
            offsetToData: 0,
            dataLength: frameData.count,
            flags: kCMBlockBufferAssureMemoryNowFlag,
            blockBufferOut: &blockBuffer
        )
        guard createStatus == kCMBlockBufferNoErr, let block = blockBuffer else { return nil }

        // Copy the compressed bytes into the block buffer's own memory
        frameData.withUnsafeBytes { rawPtr in
            guard let src = rawPtr.baseAddress else { return }
            createStatus = CMBlockBufferReplaceDataBytes(
                with: src,
                blockBuffer: block,
                offsetIntoDestination: 0,
                dataLength: frameData.count
            )
        }
        guard createStatus == kCMBlockBufferNoErr else { return nil }

        // Create CMSampleBuffer
        var sampleBuffer: CMSampleBuffer?
        var sampleSize = frameData.count
        var timingInfo = CMSampleTimingInfo(
            duration: CMTime.invalid,
            presentationTimeStamp: CMTime(seconds: timestamp, preferredTimescale: 90000),
            decodeTimeStamp: CMTime.invalid
        )

        CMSampleBufferCreateReady(
            allocator: kCFAllocatorDefault,
            dataBuffer: block,
            formatDescription: formatDesc,
            sampleCount: 1,
            sampleTimingEntryCount: 1,
            sampleTimingArray: &timingInfo,
            sampleSizeEntryCount: 1,
            sampleSizeArray: &sampleSize,
            sampleBufferOut: &sampleBuffer
        )

        guard let sample = sampleBuffer else { return nil }

        // Decode synchronously
        decodedFrame = nil
        var flagsOut = VTDecodeInfoFlags()
        let decodeStatus = VTDecompressionSessionDecodeFrame(
            session,
            sampleBuffer: sample,
            flags: [._EnableAsynchronousDecompression],
            infoFlagsOut: &flagsOut
        ) { [weak self] decStatus, _, decodedImage, _, _ in
            guard decStatus == noErr, let decodedImage = decodedImage else { return }
            self?.decodedFrame = decodedImage
        }

        guard decodeStatus == noErr else { return nil }
        VTDecompressionSessionWaitForAsynchronousFrames(session)

        return decodedFrame
    }

    /// Create a CMFormatDescription from raw SPS/PPS parameter set data.
    private func createFormatDescription(from paramData: Data) -> CMFormatDescription? {
        // Parse NAL units from the parameter data
        var paramSets: [Data] = []
        var currentStart: Int?

        let bytes = [UInt8](paramData)
        for i in 0..<bytes.count {
            // Look for start codes 0x00 0x00 0x00 0x01
            if i + 3 < bytes.count &&
               bytes[i] == 0x00 && bytes[i+1] == 0x00 &&
               bytes[i+2] == 0x00 && bytes[i+3] == 0x01 {
                if let start = currentStart {
                    paramSets.append(Data(bytes[start..<i]))
                }
                currentStart = i + 4
            }
        }
        if let start = currentStart {
            paramSets.append(Data(bytes[start...]))
        }

        guard !paramSets.isEmpty else { return nil }

        let pointers = paramSets.map { data -> UnsafePointer<UInt8> in
            data.withUnsafeBytes { $0.baseAddress!.assumingMemoryBound(to: UInt8.self) }
        }
        let sizes = paramSets.map { $0.count }

        var formatDesc: CMFormatDescription?
        // Need to keep data alive during the call
        let status = paramSets.withUnsafeBufferPointers { (ptrs, szs) -> OSStatus in
            CMVideoFormatDescriptionCreateFromH264ParameterSets(
                allocator: kCFAllocatorDefault,
                parameterSetCount: ptrs.count,
                parameterSetPointers: ptrs.baseAddress!,
                parameterSetSizes: szs.baseAddress!,
                nalUnitHeaderLength: 4,
                formatDescriptionOut: &formatDesc
            )
        }

        return status == noErr ? formatDesc : nil
    }

    private func isKey(_ fd1: CMFormatDescription, differentFrom fd2: CMFormatDescription) -> Bool {
        !CMFormatDescriptionEqual(fd1, otherFormatDescription: fd2)
    }

    // MARK: - Marking

    /// Marks the current READ position (delayed frame) as a key point.
    func markCurrentFrame() -> Int {
        lock.lock()
        let frameIdx = max(0, totalFramesWritten - delayFrameCount)
        markedIndices.append(frameIdx)
        lock.unlock()
        return frameIdx
    }

    // MARK: - Reset

    func reset() {
        lock.lock()
        for i in 0..<capacity {
            buffer[i] = nil
        }
        writeIndex = 0
        totalFramesWritten = 0
        markedIndices = []
        lastDecodedBufferIndex = -1
        lock.unlock()
    }

    /// Updates the delay frame count.
    func updateDelay(_ newDelayFrameCount: Int) {
        lock.lock()
        delayFrameCount = newDelayFrameCount
        lock.unlock()
    }

    // MARK: - Memory Estimation

    /// Estimates max buffer capacity using compressed frame sizes.
    static func estimateMaxCapacity(
        resolution: VideoResolution,
        fps: FrameRate,
        delaySeconds: Double
    ) -> (maxFrames: Int, maxDuration: TimeInterval) {
        let availableMemory = os_proc_available_memory()
        let usableMemory = Int(Double(availableMemory) * VIRConstants.memoryUsageFraction)

        // Compressed H.264 frame: ~10-50 KB on average, use 30 KB as estimate
        let compressedFrameSize = VIRConstants.compressedFrameSizeEstimate

        let maxFrames = usableMemory / compressedFrameSize
        let maxDuration = TimeInterval(maxFrames) / TimeInterval(fps.rawValue)

        return (maxFrames, maxDuration)
    }
}



// MARK: - Helper for parameter set pointer extraction

// MARK: - Helper for parameter set pointer extraction

private extension Array where Element == Data {
    func withUnsafeBufferPointers<R>(_ body: (UnsafeBufferPointer<UnsafePointer<UInt8>>, UnsafeBufferPointer<Int>) -> R) -> R {
        let count = self.count
        // Use temporary allocation to avoid manual allocate/deallocate and unused warnings
        return withUnsafeTemporaryAllocation(of: UnsafePointer<UInt8>.self, capacity: count) { pointers in
            return withUnsafeTemporaryAllocation(of: Int.self, capacity: count) { sizes in
                for (i, data) in self.enumerated() {
                    let nsData = data as NSData
                    pointers[i] = nsData.bytes.assumingMemoryBound(to: UInt8.self)
                    sizes[i] = data.count
                }
                
                // Convert MutableBufferPointer to BufferPointer for the callback
                let immPointers = UnsafeBufferPointer(start: pointers.baseAddress, count: count)
                let immSizes = UnsafeBufferPointer(start: sizes.baseAddress, count: count)
                return body(immPointers, immSizes)
            }
        }
    }
}
