import SwiftUI
import PencilKit
import SwiftData

struct DrawingToolBar: View {
    @Binding var currentTool: PKTool
    @Binding var isDrawing: Bool
    @Binding var drawing: PKDrawing
    @Binding var drawingMode: DrawingMode
    @Binding var overlayColor: Color
    @Binding var overlayLineWidth: CGFloat
    @Binding var straightLines: [LineSegment]
    @Binding var angleMeasurements: [AngleMeasurement]
    
    // Undo callbacks for line & angle modes
    var onUndoLine: (() -> Void)?
    var onUndoAngle: (() -> Void)?
    
    // For Templates
    @Query private var templates: [ReferenceDrawing]
    @Environment(\.modelContext) private var modelContext
    
    @State private var selectedColor: Color = .red
    @State private var lineWidth: CGFloat = 5.0
    @State private var showSaveDialog = false
    @State private var newTemplateName = ""
    @State private var showLoadDialog = false
    
    var body: some View {
        VStack(spacing: 10) {
            // MARK: - Tool Mode Selector
            HStack(spacing: 4) {
                ForEach(DrawingMode.allCases) { mode in
                    Button {
                        drawingMode = mode
                        updateToolForMode()
                    } label: {
                        VStack(spacing: 2) {
                            Image(systemName: mode.systemImage)
                                .font(.title3)
                            Text(mode.label)
                                .font(.system(size: 9, weight: .medium))
                        }
                        .frame(width: 52, height: 40)
                        .foregroundStyle(drawingMode == mode ? .white : .gray)
                        .background(drawingMode == mode ? Color.orange.opacity(0.6) : Color.clear)
                        .cornerRadius(8)
                    }
                }
            }
            
            // MARK: - Tool Options
            HStack(spacing: 16) {
                ColorPicker("", selection: $selectedColor)
                    .labelsHidden()
                
                Slider(value: $lineWidth, in: 2...20)
                    .frame(width: 100)
                
                // Undo for current mode
                if drawingMode == .pen || drawingMode == .eraser {
                    Button {
                        drawing = PKDrawing()
                        straightLines.removeAll()
                        angleMeasurements.removeAll()
                    } label: {
                        Image(systemName: "trash.circle")
                            .font(.title2)
                            .foregroundStyle(.red)
                    }
                } else if drawingMode == .line {
                    Button {
                        onUndoLine?()
                    } label: {
                        Image(systemName: "arrow.uturn.backward.circle")
                            .font(.title2)
                            .foregroundStyle(.yellow)
                    }
                } else if drawingMode == .angle {
                    Button {
                        onUndoAngle?()
                    } label: {
                        Image(systemName: "arrow.uturn.backward.circle")
                            .font(.title2)
                            .foregroundStyle(.yellow)
                    }
                }
                
                Divider()
                    .frame(height: 24)
                
                // Save / Load templates (pen drawings only)
                Button {
                    newTemplateName = "Reference \(Date().formatted(date: .numeric, time: .shortened))"
                    showSaveDialog = true
                } label: {
                    Image(systemName: "square.and.arrow.down.fill")
                        .font(.title2)
                        .foregroundStyle(.white)
                }
                
                Button {
                    showLoadDialog = true
                } label: {
                    Image(systemName: "folder.fill")
                        .font(.title2)
                        .foregroundStyle(.white)
                }
                
                Button {
                    withAnimation {
                        isDrawing = false
                    }
                } label: {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.title2)
                        .foregroundStyle(.green)
                }
            }
        }
        .padding()
        .frame(minWidth: 300)
        .background(.ultraThinMaterial)
        .cornerRadius(12)
        .onChange(of: selectedColor) {
            updateToolForMode()
            overlayColor = selectedColor
        }
        .onChange(of: lineWidth) {
            updateToolForMode()
            overlayLineWidth = lineWidth
        }
        .onAppear {
            updateToolForMode()
            overlayColor = selectedColor
            overlayLineWidth = lineWidth
        }
        
        // Save Dialog
        .alert("Save Template", isPresented: $showSaveDialog) {
            TextField("Template Name", text: $newTemplateName)
            Button("Save") {
                saveTemplate()
            }
            Button("Cancel", role: .cancel) { }
        }
        
        // Load Sheet
        .sheet(isPresented: $showLoadDialog) {
            NavigationStack {
                List {
                    ForEach(templates) { template in
                        Button {
                            loadTemplate(template)
                            showLoadDialog = false
                        } label: {
                            Text(template.name)
                        }
                    }
                    .onDelete(perform: deleteTemplate)
                }
                .navigationTitle("Load Reference")
                .toolbar {
                    Button("Cancel") { showLoadDialog = false }
                }
            }
            .presentationDetents([.medium])
        }
    }
    
    // MARK: - Helpers
    
    private func updateToolForMode() {
        switch drawingMode {
        case .pen:
            currentTool = PKInkingTool(.pen, color: UIColor(selectedColor), width: lineWidth)
        case .eraser:
            currentTool = PKEraserTool(.bitmap)
        case .line, .angle:
            // These modes use custom overlays, but we still set the pen tool
            // so that if the user switches back, the color/width are preserved.
            currentTool = PKInkingTool(.pen, color: UIColor(selectedColor), width: lineWidth)
        }
    }

    
    private func saveTemplate() {
        let drawData = drawing.dataRepresentation()
        let lData = try? JSONEncoder().encode(straightLines)
        let aData = try? JSONEncoder().encode(angleMeasurements)
        let template = ReferenceDrawing(name: newTemplateName, drawingData: drawData, linesData: lData, anglesData: aData)
        modelContext.insert(template)
    }
    
    private func loadTemplate(_ template: ReferenceDrawing) {
        if let newDrawing = try? PKDrawing(data: template.drawingData) {
            drawing = newDrawing
        }
        if let lData = template.linesData,
           let loadedLines = try? JSONDecoder().decode([LineSegment].self, from: lData) {
            straightLines = loadedLines
        } else {
            straightLines.removeAll()
        }
        if let aData = template.anglesData,
           let loadedAngles = try? JSONDecoder().decode([AngleMeasurement].self, from: aData) {
            angleMeasurements = loadedAngles
        } else {
            angleMeasurements.removeAll()
        }
    }
    
    private func deleteTemplate(at offsets: IndexSet) {
        for index in offsets {
            let template = templates[index]
            modelContext.delete(template)
        }
    }
}
