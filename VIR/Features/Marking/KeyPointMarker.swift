import Foundation

/// Manages key point markers during a recording session.
class KeyPointMarker {
    private(set) var keyPoints: [KeyPoint] = []

    /// Adds a new mark at the given frame/timestamp
    func addMark(frameIndex: Int, timestamp: TimeInterval, source: MarkSource) -> KeyPoint {
        let kp = KeyPoint(
            timestamp: timestamp,
            frameIndex: frameIndex,
            source: source
        )
        keyPoints.append(kp)
        return kp
    }

    /// Removes the last mark (undo)
    @discardableResult
    func undoLastMark() -> KeyPoint? {
        keyPoints.isEmpty ? nil : keyPoints.removeLast()
    }

    /// Returns marks sorted by timestamp
    var sortedMarks: [KeyPoint] {
        keyPoints.sorted { $0.timestamp < $1.timestamp }
    }

    /// Reset all marks
    func reset() {
        keyPoints.removeAll()
    }

    /// Number of marks
    var count: Int { keyPoints.count }
}
