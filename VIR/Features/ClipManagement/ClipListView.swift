import SwiftUI
import AVKit

/// Post-session clip list showing auto-generated segments.
struct ClipListView: View {
    let clips: [Clip]
    let arrowHits: [ArrowHit]
    let onSelectClip: (Clip) -> Void
    let onDismiss: () -> Void
    
    // Helper to find hit for a clip
    func hit(for clip: Clip) -> ArrowHit? {
        guard let hitId = clip.linkedArrowHitId else { return nil }
        return arrowHits.first { $0.id == hitId }
    }

    var body: some View {
        NavigationStack {
            Group {
                if clips.isEmpty {
                    ContentUnavailableView(
                        "No Clips",
                        systemImage: "film",
                        description: Text("No key points were marked during this session. Mark key points during recording to create clips.")
                    )
                } else {
                    List {
                        ForEach(Array(clips.enumerated()), id: \.element.id) { index, clip in
                            Button {
                                onSelectClip(clip)
                            } label: {
                                HStack(spacing: 12) {
                                    // Thumbnail placeholder
                                    ZStack {
                                        RoundedRectangle(cornerRadius: 8)
                                            .fill(Color.gray.opacity(0.3))
                                            .frame(width: 80, height: 60)
                                        
                                        if let hit = hit(for: clip) {
                                            // Overlay score on thumbnail
                                            Circle()
                                                .fill(hit.ringScore == 10 ? Color.yellow : (hit.ringScore >= 9 ? Color.yellow : (hit.ringScore >= 7 ? Color.red : (hit.ringScore >= 5 ? Color.blue : Color.black))))
                                                .frame(width: 30, height: 30)
                                                .overlay(
                                                    Text(hit.scoreDisplay)
                                                        .font(.caption).bold()
                                                        .foregroundStyle(hit.ringScore >= 9 ? .black : .white)
                                                )
                                                .offset(x: 25, y: -15) // Corner badge
                                        } else {
                                            Image(systemName: "play.fill")
                                                .foregroundStyle(.white)
                                        }
                                    }

                                    VStack(alignment: .leading, spacing: 4) {
                                        Text("Clip \(index + 1)")
                                            .font(.headline)
                                        
                                        if let hit = self.hit(for: clip) {
                                            Text("Score: \(hit.scoreDisplay)")
                                                .font(.subheadline)
                                                .foregroundStyle(.primary)
                                        }

                                        Text("\(clip.startTime.preciseText) – \(clip.endTime.preciseText)")
                                            .font(.caption)
                                            .foregroundStyle(.secondary)

                                        Text(clip.durationText)
                                            .font(.caption2)
                                            .foregroundStyle(.tertiary)
                                    }

                                    Spacer()

                                    Image(systemName: "chevron.right")
                                        .foregroundStyle(.secondary)
                                }
                                .padding(.vertical, 4)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
            .navigationTitle("Clips (\(clips.count))")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { onDismiss() }
                }
            }
        }
    }
}
