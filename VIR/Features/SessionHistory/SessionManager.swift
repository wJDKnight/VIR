import Foundation
import SwiftData
import os

/// Manages session persistence and file operations.
@MainActor
class SessionManager {
    private let modelContext: ModelContext
    
    init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }
    
    /// Deletes a session and all its associated video files from disk.
    func deleteSession(_ session: Session) {
        // Delete video files for each clip
        for clip in session.clips {
            if let fileName = clip.fileName {
                let fileURL = VIRConstants.clipsDirectory.appendingPathComponent(fileName)
                do {
                    try FileManager.default.removeItem(at: fileURL)
                    os_log(.info, "Deleted clip file: %{public}@", fileURL.path)
                } catch {
                    os_log(.error, "Failed to delete clip file: %{public}@, error: %{public}@", fileURL.path, error.localizedDescription)
                }
            }
        }
        
        // Delete the session from SwiftData
        modelContext.delete(session)
    }
    
    /// Deletes a single clip from a session, removing both the file and the database record.
    func deleteClip(_ clip: Clip, from session: Session) {
        // 1. Delete the video file
        if let fileName = clip.fileName {
            let fileURL = VIRConstants.clipsDirectory.appendingPathComponent(fileName)
            do {
                try FileManager.default.removeItem(at: fileURL)
                os_log(.info, "Deleted clip file: %{public}@", fileURL.path)
            } catch {
                os_log(.error, "Failed to delete clip file: %{public}@, error: %{public}@", fileURL.path, error.localizedDescription)
            }
        }
        
        // 2. Remove from session's array
        if let index = session.clips.firstIndex(where: { $0.id == clip.id }) {
            session.clips.remove(at: index)
        }
        
        // 3. Remove linked ArrowHit if exists
        if let hitId = clip.linkedArrowHitId,
           let hitIndex = session.arrowHits.firstIndex(where: { $0.id == hitId }) {
            let hit = session.arrowHits[hitIndex]
            session.arrowHits.remove(at: hitIndex)
            modelContext.delete(hit)
            
            // 4. Update Total Score
            session.totalScore = session.arrowHits.reduce(0) { $0 + $1.ringScore }
        }
        
        // 5. Delete from ModelContext
        modelContext.delete(clip)
    }
    
    /// Calculates the total storage used by all sessions in the database.
    static func calculateTotalStorage(in context: ModelContext) -> Int64 {
        let descriptor = FetchDescriptor<Session>()
        do {
            let sessions = try context.fetch(descriptor)
            return sessions.reduce(0) { $0 + $1.totalSize }
        } catch {
            os_log(.error, "Failed to fetch sessions for storage calculation: %{public}@", error.localizedDescription)
            return 0
        }
    }
}
