import Foundation
import SwiftData
import PencilKit

@Model
class ReferenceDrawing {
    var id: UUID
    var name: String
    var createdAt: Date
    var drawingData: Data // Serialized PKDrawing
    var linesData: Data?  // Serialized [LineSegment]
    var anglesData: Data? // Serialized [AngleMeasurement]
    
    init(id: UUID = UUID(), name: String, createdAt: Date = Date(), drawingData: Data, linesData: Data? = nil, anglesData: Data? = nil) {
        self.id = id
        self.name = name
        self.createdAt = createdAt
        self.drawingData = drawingData
        self.linesData = linesData
        self.anglesData = anglesData
    }
}
