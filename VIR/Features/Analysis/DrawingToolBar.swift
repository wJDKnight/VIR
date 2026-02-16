import SwiftUI
import PencilKit
import SwiftData

struct DrawingToolBar: View {
    @Binding var currentTool: PKTool
    @Binding var isDrawing: Bool
    @Binding var drawing: PKDrawing
    
    // For Templates
    @Query private var templates: [ReferenceDrawing]
    @Environment(\.modelContext) private var modelContext
    
    @State private var selectedColor: Color = .red
    @State private var lineWidth: CGFloat = 5.0
    @State private var showSaveDialog = false
    @State private var newTemplateName = ""
    @State private var showLoadDialog = false
    
    var body: some View {
        HStack(spacing: 20) {
            // MARK: - Tool Selection
            Button {
                currentTool = PKEraserTool(.bitmap)
            } label: {
                Image(systemName: "eraser.fill")
                    .font(.title2)
                    .foregroundStyle(isEraser ? .white : .gray)
            }
            
            ColorPicker("", selection: $selectedColor)
                .labelsHidden()
            
            Slider(value: $lineWidth, in: 2...20)
                .frame(width: 100)
            
            // MARK: - Actions
            Spacer()
            
            Button("Clear") {
                drawing = PKDrawing()
            }
            
            Button("Save As Template") {
                newTemplateName = "Reference \(Date().formatted(date: .numeric, time: .shortened))"
                showSaveDialog = true
            }
            
            Button("Load Template") {
                showLoadDialog = true
            }
            
            Button("Done") {
                withAnimation {
                    isDrawing = false
                }
            }
            .fontWeight(.bold)
        }
        .padding()
        .background(.ultraThinMaterial)
        .cornerRadius(12)
        .onChange(of: selectedColor) { updateTool() }
        .onChange(of: lineWidth) { updateTool() }
        .onAppear { updateTool() }
        
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
    
    private var isEraser: Bool {
        return currentTool is PKEraserTool
    }
    
    private func updateTool() {
        if !isEraser {
            currentTool = PKInkingTool(.pen, color: UIColor(selectedColor), width: lineWidth)
        }
    }
    
    private func saveTemplate() {
        let data = drawing.dataRepresentation()
        let template = ReferenceDrawing(name: newTemplateName, drawingData: data)
        modelContext.insert(template)
    }
    
    private func loadTemplate(_ template: ReferenceDrawing) {
        if let newDrawing = try? PKDrawing(data: template.drawingData) {
            drawing = newDrawing
        }
    }
    
    private func deleteTemplate(at offsets: IndexSet) {
        for index in offsets {
            let template = templates[index]
            modelContext.delete(template)
        }
    }
}
