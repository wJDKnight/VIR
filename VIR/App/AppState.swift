import Foundation
import SwiftUI

/// Global app state shared across the app via the environment.
@Observable
@MainActor
class AppState {
    var mode: AppMode = .idle
    var currentSession: Session?
    var currentKeyPoints: [KeyPoint] = []
    var isShowingSettings: Bool = false

    /// Clips saved during recording (extracted at each mark)
    var savedClips: [Clip] = []

    /// URL of the full recording file (set after stopping recording)
    var recordingFileURL: URL?

    /// Reset state for a new session
    func startNewSession(settings: AppSettings) {
        let session = Session(
            resolution: settings.resolution,
            fps: settings.frameRate.rawValue,
            delaySeconds: settings.delaySeconds,
            targetFaceType: settings.targetFaceType
        )
        currentSession = session
        currentKeyPoints = []
        mode = .recording
    }

    /// End the current session
    func stopSession() {
        mode = .reviewing
    }

    /// Return to idle state
    func reset() {
        mode = .idle
        currentSession = nil
        currentKeyPoints = []
        savedClips = []
        recordingFileURL = nil
    }

    /// Add a key point mark
    func addKeyPoint(frameIndex: Int, timestamp: TimeInterval, source: MarkSource) {
        let keyPoint = KeyPoint(
            timestamp: timestamp,
            frameIndex: frameIndex,
            source: source
        )
        currentKeyPoints.append(keyPoint)
    }
}
