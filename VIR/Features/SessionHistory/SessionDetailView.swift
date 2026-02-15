import SwiftUI
import AVKit

struct SessionDetailView: View {
    let session: Session
    @State private var exportStatus: String?
    var body: some View {
        List(session.clips) { clip in
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
