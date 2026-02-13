import SwiftUI
import AVKit

/// Post-session clip list showing auto-generated segments.
struct ClipListView: View {
    let clips: [Clip]
    let onSelectClip: (Clip) -> Void
    let onDismiss: () -> Void

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
                                    RoundedRectangle(cornerRadius: 8)
                                        .fill(Color.gray.opacity(0.3))
                                        .frame(width: 80, height: 60)
                                        .overlay {
                                            Image(systemName: "play.fill")
                                                .foregroundStyle(.white)
                                        }

                                    VStack(alignment: .leading, spacing: 4) {
                                        Text("Clip \(index + 1)")
                                            .font(.headline)

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
