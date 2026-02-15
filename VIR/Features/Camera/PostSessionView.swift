import SwiftUI

/// Post-session view shown after stopping a recording.
/// Displays clips that were saved during recording (at each mark).
struct PostSessionView: View {
    @Environment(AppState.self) private var appState
    @State private var selectedClip: Clip?
    @State private var isScoring = true

    var body: some View {
        Group {
            if appState.savedClips.isEmpty {
                VStack(spacing: 16) {
                    Image(systemName: "film")
                        .font(.system(size: 48))
                        .foregroundStyle(.gray)

                    Text("No Clips")
                        .font(.headline)
                        .foregroundStyle(.secondary)

                    Text("No key points were marked during this session.\nMark key points during recording to create clips.")
                        .font(.subheadline)
                        .foregroundStyle(.tertiary)
                        .multilineTextAlignment(.center)

                    Button("Done") {
                        appState.reset()
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.orange)
                    .padding(.top, 8)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color.black)
            } else if isScoring && !appState.savedClips.isEmpty {
                TargetScoringView(
                    targetType: appState.currentSession?.targetFaceType ?? .wa122,
                    recordedClips: appState.savedClips,
                    onComplete: { hits, score in
                        // Save hits and link to session/clips
                        appState.currentSession?.arrowHits = hits
                        appState.currentSession?.totalScore = score
                        
                        // Update in-memory clips with the link back to the hit
                        for hit in hits {
                            if let clipId = hit.linkedClipId,
                               let clipIndex = appState.savedClips.firstIndex(where: { $0.id == clipId }) {
                                appState.savedClips[clipIndex].linkedArrowHitId = hit.id
                            }
                        }
                        
                        isScoring = false
                    },
                    onSkip: {
                        isScoring = false
                    }
                )
            } else {
                ClipListView(
                    clips: appState.savedClips,
                    arrowHits: appState.currentSession?.arrowHits ?? [],
                    onSelectClip: { clip in
                        selectedClip = clip
                    },
                    onDismiss: {
                        appState.reset()
                    }
                )
                .navigationDestination(item: $selectedClip) { clip in
                    ReplayPlayerView(clip: clip)
                }
            }
        }
    }
}

// MARK: - Clip Identifiable conformance for navigation

extension Clip: Identifiable {}
