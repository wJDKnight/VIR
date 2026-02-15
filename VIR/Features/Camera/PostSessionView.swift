import SwiftUI
import SwiftData
import Foundation

/// Post-session view shown after stopping a recording.
/// Displays clips that were saved during recording (at each mark).
struct PostSessionView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.modelContext) private var modelContext
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
                SessionReviewView(
                    session: appState.currentSession ?? Session(),
                    onSave: {
                        // Persist changes
                        if let session = appState.currentSession {
                            // Ensure clips are attached to the session
                            session.clips = appState.savedClips
                            
                            // Explicitly set inverse relationship
                            for clip in session.clips {
                                clip.session = session
                            }
                            
                            // Debug logging
                            print("Saving session: \(session.id)")
                            print("  - Title: \(session.title)")
                            print("  - Clip count: \(session.clips.count)")
                            print("  - Hit count: \(session.arrowHits.count)")
                            
                            // Update debugging
                            print("Updating session: \(session.id)")
                            
                            // Session is already inserted by MainCameraScreen
                            // But we ensure it's still tracked
                            if session.modelContext == nil {
                                modelContext.insert(session)
                            }
                            
                            // Explicitly connect hits (these might be new)
                            for hit in session.arrowHits {
                                hit.session = session
                                if hit.modelContext == nil {
                                    modelContext.insert(hit)
                                }
                            }
                            
                            do {
                                try modelContext.save()
                                print("✅ Session updated successfully in Review!")
                            } catch {
                                print("❌ Failed to update session: \(error.localizedDescription)")
                                // Resulting in simpler error logging to avoid compilation issues with specific keys
                                let nsError = error as NSError
                                print("  - UserInfo: \(nsError.userInfo)")
                            }
                        } else {
                            print("❌ No active session to save!")
                        }
                        appState.reset()
                    },
                    onDiscard: {
                        // Delete session and clips
                        if let session = appState.currentSession {
                            modelContext.delete(session)
                            // Also cleanup file artifacts if not handled by delete rule?
                            // Cascade rule should handle DB, but files might need manual cleanup if not using external storage manager.
                            // For now assume Cascade deletes Clip models, but files remain?
                            // Ideally SessionManager should handle delete to clean files.
                            let manager = SessionManager(modelContext: modelContext)
                            manager.deleteSession(session)
                        }
                        appState.reset()
                    }
                )
            }
        }
    }
}

// MARK: - Clip Identifiable conformance for navigation
// Conformance is now in Clip.swift
