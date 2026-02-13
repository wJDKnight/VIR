import Foundation

enum VIRConstants {
    // MARK: - Delay
    static let defaultDelay: Double = 5.0
    static let minDelay: Double = 1.0
    static let maxDelay: Double = 60.0

    // MARK: - Buffer
    static let memoryUsageFraction: Double = 0.70  // use 70% of available RAM
    static let memoryWarningThreshold: Double = 0.85  // warn at 85% usage

    // MARK: - UI
    static let hudPadding: CGFloat = 16
    static let buttonSize: CGFloat = 60
    static let markFlashDuration: Double = 0.2

    // MARK: - Compressed Buffer
    /// Estimated average compressed H.264 frame size in bytes (~30 KB)
    static let compressedFrameSizeEstimate: Int = 30_000

    // MARK: - Files
    static let clipsDirectoryName = "VIRClips"
    static let recordingsDirectoryName = "VIRRecordings"

    static var clipsDirectory: URL {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let dir = docs.appendingPathComponent(clipsDirectoryName)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    static var recordingsDirectory: URL {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let dir = docs.appendingPathComponent(recordingsDirectoryName)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }
}
