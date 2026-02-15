import Foundation
import SwiftData
import CoreGraphics

@Model
class ArrowHit {
    var id: UUID
    var sessionId: UUID
    var arrowIndex: Int         // 1-based index (Arrow 1, Arrow 2...)
    
    // Normalized position on the target face (0,0 is top-left, 1,1 is bottom-right)
    var x: Double
    var y: Double
    
    var ringScore: Int          // 0 (M), 1..10
    var isX: Bool               // Inner 10
    
    var linkedClipId: UUID?
    
    init(
        id: UUID = UUID(),
        sessionId: UUID = UUID(),
        arrowIndex: Int = 1,
        x: Double = 0.5,
        y: Double = 0.5,
        ringScore: Int = 0,
        isX: Bool = false,
        linkedClipId: UUID? = nil
    ) {
        self.id = id
        self.sessionId = sessionId
        self.arrowIndex = arrowIndex
        self.x = x
        self.y = y
        self.ringScore = ringScore
        self.isX = isX
        self.linkedClipId = linkedClipId
    }
    
    var position: CGPoint {
        get { CGPoint(x: x, y: y) }
        set { x = newValue.x; y = newValue.y }
    }
    
    var scoreDisplay: String {
        if ringScore == 0 { return "M" }
        if isX { return "X" }
        return String(ringScore)
    }
}
