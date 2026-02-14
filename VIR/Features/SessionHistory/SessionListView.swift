import SwiftUI
import SwiftData
import os

struct SessionListView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Session.date, order: .reverse) private var sessions: [Session]
    @State private var totalStorageUsed: Int64 = 0
    @State private var sessionToDelete: Session?
    @State private var showDeleteConfirmation = false

    var body: some View {
        VStack(spacing: 0) {
            List {
                if sessions.isEmpty {
                    ContentUnavailableView(
                        "No Recorded Sessions",
                        systemImage: "video.slash",
                        description: Text("Recorded sessions will appear here.")
                    )
                } else {
                    ForEach(sessions) { session in
                        NavigationLink(destination: SessionDetailView(session: session)) {
                            SessionRow(session: session)
                        }
                    }
                    .onDelete(perform: confirmDelete)
                }
            }
            .listStyle(.plain)
            
            // Footer
            VStack {
                Divider()
                HStack {
                    Text("Total Storage:")
                    Spacer()
                    Text(ByteCountFormatter.string(fromByteCount: totalStorageUsed, countStyle: .file))
                        .foregroundStyle(.secondary)
                }
                .font(.footnote)
                .padding()
                .background(.regularMaterial)
            }
        }
        .navigationTitle("Session History")
        .onAppear {
            calculateStorage()
        }
        .onChange(of: sessions) {
            calculateStorage()
        }
        .confirmationDialog(
            "Delete Session?",
            isPresented: $showDeleteConfirmation,
            titleVisibility: .visible
        ) {
            Button("Delete Session", role: .destructive) {
                if let session = sessionToDelete {
                    deleteSession(session)
                }
            }
            Button("Cancel", role: .cancel) {
                sessionToDelete = nil
            }
        } message: {
            Text("This will permanently delete the session and all recorded videos.")
        }
    }

    private func confirmDelete(offsets: IndexSet) {
        if let index = offsets.first {
            sessionToDelete = sessions[index]
            showDeleteConfirmation = true
        }
    }

    private func deleteSession(_ session: Session) {
        let manager = SessionManager(modelContext: modelContext)
        manager.deleteSession(session)
        calculateStorage()
        sessionToDelete = nil
    }

    private func calculateStorage() {
        totalStorageUsed = SessionManager.calculateTotalStorage(in: modelContext)
    }
}

struct SessionRow: View {
    let session: Session

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(session.date.formatted(date: .abbreviated, time: .shortened))
                .font(.headline)
            
            HStack {
                Label("\(session.clips.count) clips", systemImage: "film")
                Spacer()
                Label(ByteCountFormatter.string(fromByteCount: session.totalSize, countStyle: .file), systemImage: "internaldrive")
            }
            .font(.caption)
            .foregroundStyle(.secondary)
        }
        .padding(.vertical, 4)
    }
}
