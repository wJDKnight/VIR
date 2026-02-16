import SwiftUI
import PencilKit

struct DrawingCanvasView: UIViewRepresentable {
    @Binding var drawing: PKDrawing
    var tool: PKTool
    var isUserInteractionEnabled: Bool = true
    
    func makeUIView(context: Context) -> PKCanvasView {
        let canvas = PKCanvasView()
        canvas.drawingPolicy = .anyInput
        canvas.backgroundColor = .clear
        canvas.isOpaque = false // Transparent background
        canvas.delegate = context.coordinator
        
        // Hide the default tool picker if we manage tools manually
        // But typically we want the default tool picker for full features.
        // User asked for "Freehand drawing lines ... color, thickness options".
        // PKToolPicker is the standard way, but we can also use custom toolbar if we want to restrict tools.
        // For simplicity and feature-richness, let's start by setting the tool programmatically from a custom toolbar 
        // as requested ("Add tools to start Freehand drawing lines...").
        
        return canvas
    }
    
    func updateUIView(_ uiView: PKCanvasView, context: Context) {
        // Avoid update loops by checking equality if possible, but PKDrawing is a value type.
        // Direct assignment on every update might be heavy if not careful, but usually okay for small drawings.
        if uiView.drawing != drawing {
           uiView.drawing = drawing
        }
        
        uiView.tool = tool
        uiView.isUserInteractionEnabled = isUserInteractionEnabled
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, PKCanvasViewDelegate {
        var parent: DrawingCanvasView
        
        init(_ parent: DrawingCanvasView) {
            self.parent = parent
        }
        
        func canvasViewDrawingDidChange(_ canvasView: PKCanvasView) {
            DispatchQueue.main.async {
                self.parent.drawing = canvasView.drawing
            }
        }
    }
}
