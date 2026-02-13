import Foundation
import SwiftData

@Model
class ArrowHit {
    var id: UUID
    var sessionId: UUID
    var positionX: Double       // normalized 0...1 on target face
    var positionY: Double       // normalized 0...1 on target face
    var ringScore: Int          // 0 (miss) to 10, or 11 for X
    var arrowIndex: Int         // order within the round
    var linkedClipId: UUID?

    init(
        id: UUID = UUID(),
        sessionId: UUID,
        positionX: Double,
        positionY: Double,
        ringScore: Int,
        arrowIndex: Int,
        linkedClipId: UUID? = nil
    ) {
        self.id = id
        self.sessionId = sessionId
        self.positionX = positionX
        self.positionY = positionY
        self.ringScore = ringScore
        self.arrowIndex = arrowIndex
        self.linkedClipId = linkedClipId
    }

    var scoreDisplayText: String {
        switch ringScore {
        case 11: return "X"
        case 0: return "M"
        default: return "\(ringScore)"
        }
    }
}
