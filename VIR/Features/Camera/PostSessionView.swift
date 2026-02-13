import SwiftUI

/// Post-session view shown after stopping a recording.
/// Displays clips that were saved during recording (at each mark).
struct PostSessionView: View {
    @Environment(AppState.self) private var appState
    @State private var selectedClip: Clip?

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
            } else {
                ClipListView(
                    clips: appState.savedClips,
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
