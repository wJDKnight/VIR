import Foundation
import SwiftData

@Model
class Clip: Identifiable {
    var id: UUID
    var sessionId: UUID
    var startTime: TimeInterval
    var endTime: TimeInterval
    var fileName: String?       // Store filename relative to VIRConstants.clipsDirectory
    var fileSize: Int64         // Size in bytes
    var linkedArrowHitId: UUID?
    
    // Inverse relationship (unwrapped optional to allow temporary detachment)
    var session: Session?
    
    init(
        id: UUID = UUID(),
        sessionId: UUID,
        startTime: TimeInterval,
        endTime: TimeInterval,
        fileName: String? = nil,
        fileSize: Int64 = 0,
        linkedArrowHitId: UUID? = nil
    ) {
        self.id = id
        self.sessionId = sessionId
        self.startTime = startTime
        self.endTime = endTime
        self.fileName = fileName
        self.fileSize = fileSize
        self.linkedArrowHitId = linkedArrowHitId
    }

    /// Reconstructs the full file URL from the stored filename
    var fileURL: URL? {
        guard let fileName = fileName else { return nil }
        return VIRConstants.clipsDirectory.appendingPathComponent(fileName)
    }

    var durationText: String {
        let duration = endTime - startTime
        return String(format: "%.1fs", duration)
    }
}
