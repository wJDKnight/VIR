import SwiftUI
import AVKit

struct SessionDetailView: View {
    let session: Session
    @State private var exportStatus: String?
    
    var body: some View {
        List {
            if !session.arrowHits.isEmpty {
                Section {
                    HStack {
                        Spacer()
                        ZStack {
                            TargetFaceView(type: session.targetFaceType)
                                .frame(width: 300, height: 300)
                            
                            // Hit Markers
                            GeometryReader { geometry in
                                ForEach(session.arrowHits) { hit in
                                    Circle()
                                        .fill(Color.green)
                                        .frame(width: 8, height: 8)
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
            NavigationLink(destination: ReplayPlayerView(clip: clip)) {
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
                    }
                }
            }
        }
        }
        .navigationTitle(session.date.formatted(date: .abbreviated, time: .shortened))
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
