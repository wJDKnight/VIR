import SwiftUI
import SwiftData

struct SessionReviewView: View {
    @Environment(\.modelContext) private var modelContext
    @Bindable var session: Session
    var onSave: () -> Void
    var onDiscard: () -> Void
    
    @State private var selectedArrowIndex: Int? = nil
    
    // Drag state for editing
    @State private var currentDragLocation: CGPoint? = nil
    
    // State to track which clip we are currently scoring (if adding new hits)
    // If nil, we are not in specific "add mode" but can edit.
    // However, the user wants a flow. Let's track the "next" clip index to score.
    @State private var scoringCliffIndex: Int = 0

    private var sortedClips: [Clip] {
        session.clips.sorted { $0.startTime < $1.startTime }
    }
    
    // Derived: which clip corresponds to the next hit?
    private var nextClipToScore: Clip? {
        let hitCount = session.arrowHits.count
        if hitCount < sortedClips.count {
            return sortedClips[hitCount]
        }
        return nil
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    titleAndNoteSection
                }
                .listRowBackground(Color.clear)
                .listRowInsets(EdgeInsets())
                
                Section {
                    targetSection
                }
                .listRowBackground(Color.clear)
                .listRowInsets(EdgeInsets())
                
                Section("Clips (\(session.clips.count))") {
                    ForEach(sortedClips, id: \.id) { clip in
                        NavigationLink(destination: ClipReplayView(clip: clip)) {
                           HStack {
                               VStack(alignment: .leading) {
                                   Text("Clip \(clip.durationText)") // Using duration or index? sortedClips loses index if not enumerated
                                            // But since we want "Clip 1, Clip 2", we need index.
                                            // Let's use enumerated() in ForEach or derive index.
                                            // SwiftUI List ForEach with index:
                                            // We can find index in sortedClips.
                                   let index = sortedClips.firstIndex(where: {$0.id == clip.id}) ?? 0
                                   
                                   Text("Clip \(index + 1)")
                                       .font(.body)
                                       .foregroundColor(.primary)
                                   Text(clip.durationText)
                                       .font(.caption)
                                       .foregroundStyle(.secondary)
                               }
                               Spacer()
                               
                               if let hitId = clip.linkedArrowHitId,
                                  let hit = session.arrowHits.first(where: { $0.id == hitId }) {
                                   Text(hit.scoreDisplay)
                                       .bold()
                                       .padding(6)
                                       .background(Color.green.opacity(0.1))
                                       .cornerRadius(4)
                                       .foregroundColor(.primary)
                               }
                           }
                        }
                        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
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
            .listStyle(.plain)
            .padding(.bottom, 40)
            .navigationTitle("Review Session")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Ignore", role: .destructive) {
                        onDiscard()
                    }
                    .foregroundStyle(.red)
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        onSave()
                    }
                    .bold()
                }
            }
        }
    }

    private var titleAndNoteSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            TextField("Session Title", text: $session.title)
                .font(.title2).bold()
                .textFieldStyle(.roundedBorder)
                .onAppear {
                    if session.title.isEmpty {
                        session.title = session.date.formatted(date: .abbreviated, time: .shortened)
                    }
                }
            
            TextField("Notes...", text: $session.note, axis: .vertical)
                .textFieldStyle(.roundedBorder)
                .lineLimit(3...6)
        }
        .padding()
    }

    private var targetSection: some View {
        VStack {
            HStack {
                Text("Target & Scoring")
                    .font(.headline)
                Spacer()
                if let nextClip = nextClipToScore {
                     Text("Scoring Clip \(session.arrowHits.count + 1)")
                        .font(.subheadline)
                        .foregroundStyle(.blue)
                        .bold()
                } else {
                    Text("All Clips Scored")
                        .font(.subheadline)
                        .foregroundStyle(.green)
                }
            }
            .padding(.horizontal)
            
            targetInteractionView
                .frame(height: 350)
            
            // Arrow Selector for Editing
            if !session.arrowHits.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(0..<session.arrowHits.count, id: \.self) { index in
                            Button {
                                selectedArrowIndex = (selectedArrowIndex == index) ? nil : index
                            } label: {
                                Text("\(index + 1)")
                                    .font(.headline)
                                    .frame(width: 44, height: 44)
                                    .background(selectedArrowIndex == index ? Color.accentColor : Color.gray.opacity(0.2))
                                    .foregroundStyle(selectedArrowIndex == index ? .white : .primary)
                                    .clipShape(Circle())
                            }
                        }
                        
                        // "Placeholder" for the next hit if not all scored
                        if nextClipToScore != nil && selectedArrowIndex == nil {
                             Text("Next: \(session.arrowHits.count + 1)")
                                .font(.caption)
                                .frame(width: 44, height: 44)
                                .overlay(
                                    Circle().stroke(style: StrokeStyle(lineWidth: 1, dash: [4]))
                                        .foregroundStyle(.secondary)
                                )
                        }
                    }
                    .padding(.horizontal)
                }
                .padding(.vertical, 8)
                
                if let selectedIndex = selectedArrowIndex {
                    Text("score: \(session.arrowHits[selectedIndex].scoreDisplay)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            } else {
                Text("Tap target to add hit for Clip 1")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }


    
    private var targetInteractionView: some View {
        GeometryReader { geometry in
            let size = min(geometry.size.width, geometry.size.height)
            let pixelsPerCm = size / session.targetFaceType.diameterCm
            let arrowDiameterMm = AppSettings.shared.arrowDiameterMm
            let arrowDiameterPx = (arrowDiameterMm / 10.0) * pixelsPerCm
            
            ZStack {
                // Background Target
                TargetFaceView(type: session.targetFaceType)
                    .frame(width: size, height: size)
                
                // Existing Hits
                ForEach(Array(session.arrowHits.enumerated()), id: \.element.id) { index, hit in
                    Circle()
                        .fill(selectedArrowIndex == index ? Color.blue : Color.green)
                        .frame(width: arrowDiameterPx, height: arrowDiameterPx)
                        .position(
                            x: hit.x * size,
                            y: hit.y * size
                        )
                }
                
                // Interaction Layer
                Color.clear
                    .contentShape(Rectangle())
                    .gesture(
                        DragGesture(minimumDistance: 0)
                            .onChanged { value in
                               handleDrag(value: value, size: size, arrowDiameterMm: arrowDiameterMm)
                            }
                    )
            }
            .frame(width: size, height: size)
            .position(x: geometry.size.width / 2, y: geometry.size.height / 2)
        }
    }
    
    private func handleDrag(value: DragGesture.Value, size: CGFloat, arrowDiameterMm: Double) {
        let location = value.location
        let normalizedX = max(0, min(1, location.x / size))
        let normalizedY = max(0, min(1, location.y / size))
        let point = CGPoint(x: normalizedX, y: normalizedY)
        
        let score = ScoringEngine.calculateScore(
            normalizedPoint: point,
            targetType: session.targetFaceType,
            arrowDiameterMm: arrowDiameterMm
        )
        
        // Mode 1: Edit existing hit (if selected)
        if let index = selectedArrowIndex {
            let hit = session.arrowHits[index]
            hit.x = normalizedX
            hit.y = normalizedY
            hit.ringScore = score.score
            hit.isX = score.isX
            
            // Recalculate total score
            session.totalScore = session.arrowHits.reduce(0) { $0 + $1.ringScore }
            return
        }
        
        // Mode 2: Add NEW hit for the NEXT available clip
        // Only allow adding if we have clips waiting to be scored
        let hitCount = session.arrowHits.count
        if hitCount < sortedClips.count {
            // Logic:
            // If we are dragging, we might want to update the "just added" hit if it was added in THIS gesture sequence.
            // But since we don't track gesture state across frames easily here without @State,
            // let's simplify:
            // Since `handleDrag` is called continuously, we can't just append on every frame.
            // We need to know if we are "creating" or "updating the one we just created".
            
            // A common pattern is to select the new hit immediately so future drag events edit it.
            
            // Create the new hit
            let nextIndex = session.arrowHits.count // e.g. 0 if empty
            let clip = sortedClips[nextIndex]
            
            let newHit = ArrowHit(
                sessionId: session.id,
                arrowIndex: nextIndex + 1,
                x: normalizedX,
                y: normalizedY,
                ringScore: score.score,
                isX: score.isX,
                linkedClipId: clip.id
            )
            // Explicitly set the inverse relationship
            newHit.session = session
            
            session.arrowHits.append(newHit)
            
            // IMPORTANT: Auto-select this new hit so subsequent drag events in this gesture update IT
            // instead of creating more hits.
            selectedArrowIndex = nextIndex
            
            clip.linkedArrowHitId = newHit.id
            session.totalScore = (session.totalScore ?? 0) + score.score
        }
    }
}
