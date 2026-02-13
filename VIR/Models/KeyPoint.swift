import Foundation

/// A user-defined timestamp marker in the video buffer for clipping.
/// Not persisted — only lives during an active recording session.
struct KeyPoint: Identifiable {
    let id = UUID()
    let timestamp: TimeInterval  // position in buffer timeline
    let frameIndex: Int
    let source: MarkSource       // .doubleTap | .volumeButton | .onScreenButton
    let createdAt: Date = Date()
}
