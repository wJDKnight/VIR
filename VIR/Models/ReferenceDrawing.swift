import Foundation
import SwiftData
import PencilKit

@Model
class ReferenceDrawing {
    var id: UUID
    var name: String
    var createdAt: Date
    var drawingData: Data // Serialized PKDrawing
    
    // Optional: Link to a specific clip if it's "the drawing for this clip"
    // But for templates, we might not link to a specific clip.
    // If we want to persist annotations separately from "templates", we could.
    // user asked for "save the drawing ... then ... user can restore the drawing ... to compare"
    // This implies saving templates.
    
    init(id: UUID = UUID(), name: String, createdAt: Date = Date(), drawingData: Data) {
        self.id = id
        self.name = name
        self.createdAt = createdAt
        self.drawingData = drawingData
    }
}
