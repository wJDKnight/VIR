import Foundation
import SwiftData

@Model
class Session {
    var id: UUID
    var date: Date
    var duration: TimeInterval
    var resolution: VideoResolution
    var fps: Int
    var delaySeconds: Double
    @Relationship(deleteRule: .cascade) var clips: [Clip]
    @Relationship(deleteRule: .cascade) var arrowHits: [ArrowHit]
    var totalScore: Int?
    var targetFaceType: TargetFaceType

    init(
        id: UUID = UUID(),
        date: Date = Date(),
        duration: TimeInterval = 0,
        resolution: VideoResolution = .p720,
        fps: Int = 30,
        delaySeconds: Double = 5.0,
        clips: [Clip] = [],
        arrowHits: [ArrowHit] = [],
        totalScore: Int? = nil,
        targetFaceType: TargetFaceType = .wa122
    ) {
        self.id = id
        self.date = date
        self.duration = duration
        self.resolution = resolution
        self.fps = fps
        self.delaySeconds = delaySeconds
        self.clips = clips
        self.arrowHits = arrowHits
        self.totalScore = totalScore
        self.targetFaceType = targetFaceType
    }
}
