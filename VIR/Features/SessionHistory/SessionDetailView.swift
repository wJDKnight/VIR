import SwiftUI
import AVKit

struct SessionDetailView: View {
    @Bindable var session: Session
    @Environment(\.modelContext) private var modelContext
    @State private var exportStatus: String?
    
    var body: some View {
        List {
            Section("Details") {
                TextField("Title", text: $session.title)
                    .font(.headline)
                
                TextField("Notes", text: $session.note, axis: .vertical)
                    .lineLimit(2...6)
            }

            if !session.arrowHits.isEmpty {
                Section {
                    HStack {
                        Spacer()
                        ZStack {
                            TargetFaceView(type: session.targetFaceType)
                                .frame(width: 300, height: 300)
                            
                            // Hit Markers
                            GeometryReader { geometry in
                                let size = min(geometry.size.width, geometry.size.height)
                                let pixelsPerCm = size / session.targetFaceType.diameterCm
                                // Use a default arrow size if specific session logical doesn't store it?
                                // Session doesn't store arrow diameter, assumes global setting or I need to add it to session?
                                // For now use current settings or a default.
                                // Ideally Session should record the arrow diameter used.
                                // But for now read from AppSettings (current) is the best proxy or fallback.
                                let arrowDiameterMm = AppSettings.shared.arrowDiameterMm
                                let arrowDiameterPx = (arrowDiameterMm / 10.0) * pixelsPerCm
                                
                                ForEach(session.arrowHits) { hit in
                                    Circle()
                                        .fill(Color.green)
                                        .frame(width: arrowDiameterPx, height: arrowDiameterPx)
                                        .position(
                                            x: hit.x * geometry.size.width,
                                            y: hit.y * geometry.size.height
                                        )
                                }
                            }
                            .frame(width: 300, height: 300)
                        }
                        Spacer()
                    }
                    .padding(.vertical)
                    
                    if let score = session.totalScore {
                        HStack {
                            Text("Total Score")
                            Spacer()
                            Text("\(score)")
                                .font(.title2).bold()
                        }
                    }
                } header: {
                    Text("Target")
                }
            }
            
            Section("Clips") {
                ForEach(session.clips) { clip in
            NavigationLink(destination: ClipReplayView(clip: clip)) {
                HStack {
                    VStack(alignment: .leading) {
                        Text("Clip \(clip.durationText)")
                            .font(.headline)
                        Text(clip.startTime.formatted())
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    }
                    .swipeActions {
                        Button {
                            exportClip(clip)
                        } label: {
                            Label("Save", systemImage: "square.and.arrow.up")
                        }
                        .tint(.blue)
                        
                        Button(role: .destructive) {
                            let manager = SessionManager(modelContext: modelContext)
                            manager.deleteClip(clip, from: session)
                        } label: {
                            Label("Delete", systemImage: "trash")
                        }
                    }
                }
            }
        }
        }
        .navigationTitle(session.title.isEmpty ? session.date.formatted(date: .abbreviated, time: .shortened) : session.title)
        .alert("Export Status", isPresented: .constant(exportStatus != nil), actions: {
            Button("OK") { exportStatus = nil }
        }, message: {
            Text(exportStatus ?? "")
        })
    }

    private func exportClip(_ clip: Clip) {
        guard let url = clip.fileURL else { return }
        Task {
            do {
                try await ExportManager.saveVideoToPhotoLibrary(url: url)
                exportStatus = "Saved to Photos!"
            } catch {
                exportStatus = "Export failed: \(error.localizedDescription)"
            }
        }
    }
}
