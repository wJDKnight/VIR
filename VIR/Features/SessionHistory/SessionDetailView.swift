import SwiftUI
import AVKit

struct SessionDetailView: View {
    let session: Session
    @State private var selectedClip: Clip?
    @State private var exportStatus: String?

    var body: some View {
        VStack {
            if let selectedClip, let url = selectedClip.fileURL {
                VideoPlayer(player: AVPlayer(url: url))
                    .frame(height: 300)
                    .overlay(alignment: .topTrailing) {
                        Button {
                            exportClip(selectedClip)
                        } label: {
                            Label("Save to Photos", systemImage: "square.and.arrow.up")
                                .padding(8)
                                .background(.ultraThinMaterial)
                                .cornerRadius(8)
                        }
                        .padding()
                    }
            } else {
                ContentUnavailableView(
                    "Select a Clip",
                    systemImage: "play.rectangle",
                    description: Text("Tap a clip below to play.")
                )
                .frame(height: 300)
            }

            List(session.clips) { clip in
                Button {
                    selectedClip = clip
                } label: {
                    HStack {
                        VStack(alignment: .leading) {
                            Text("Clip \(clip.durationText)")
                                .font(.headline)
                            Text(clip.startTime.formatted())
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        if selectedClip?.id == clip.id {
                            Image(systemName: "play.circle.fill")
                                .foregroundStyle(.blue)
                        }
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
