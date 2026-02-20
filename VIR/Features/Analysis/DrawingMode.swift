import Foundation

/// Defines the active drawing tool mode for the on-screen drawing overlay.
enum DrawingMode: String, CaseIterable, Identifiable {
    case pen
    case line
    case angle
    case eraser
    
    var id: String { rawValue }
    
    var label: String {
        switch self {
        case .pen: return "Pen"
        case .line: return "Line"
        case .angle: return "Angle"
        case .eraser: return "Eraser"
        }
    }
    
    var systemImage: String {
        switch self {
        case .pen: return "pencil.tip"
        case .line: return "line.diagonal"
        case .angle: return "angle"
        case .eraser: return "eraser.fill"
        }
    }
}
