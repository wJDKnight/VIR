import Foundation
import SwiftData

@Model
class Clip {
    var id: UUID
    var sessionId: UUID
    var startTime: TimeInterval
    var endTime: TimeInterval
    var fileURL: URL?           // nil until exported to disk
    var linkedArrowHitId: UUID?

    init(
        id: UUID = UUID(),
        sessionId: UUID,
        startTime: TimeInterval,
        endTime: TimeInterval,
        fileURL: URL? = nil,
        linkedArrowHitId: UUID? = nil
    ) {
        self.id = id
        self.sessionId = sessionId
        self.startTime = startTime
        self.endTime = endTime
        self.fileURL = fileURL
        self.linkedArrowHitId = linkedArrowHitId
    }

    var durationText: String {
        let duration = endTime - startTime
        return String(format: "%.1fs", duration)
    }
}
