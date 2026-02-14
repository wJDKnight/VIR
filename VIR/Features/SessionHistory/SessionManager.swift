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
