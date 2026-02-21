import SwiftUI

struct TargetScoringView: View {
    let targetType: TargetFaceType
    let recordedClips: [Clip]
    let onComplete: ([ArrowHit], Int) -> Void
    let onSkip: () -> Void
    
    @State private var arrowHits: [ArrowHit] = []
    @State private var currentArrowIndex: Int = 0
    @State private var totalScore: Int = 0
    
    // Zoom/Pan State
    // Drag Interaction State
    @State private var currentArrowLocation: CGPoint = CGPoint(x: 0.5, y: 0.5)
    
    // Zoom/Pan State (Simplified for now - can be re-enabled if needed)
    // For drag accuracy, zoom helps, but let's get the base interaction right first.
    
    private var currentClip: Clip? {
        guard currentArrowIndex < recordedClips.count else { return nil }
        return recordedClips[currentArrowIndex]
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Button("Skip") {
                    onSkip()
                }
                .foregroundStyle(.red)
                
                Spacer()
                
                Text(currentArrowIndex < recordedClips.count ? "Arrow \(currentArrowIndex + 1) of \(recordedClips.count)" : "Review")
                    .font(.headline)
                
                Spacer()
                
                // Done button only appears at the end
                Button("Done") {
                     onComplete(arrowHits, totalScore)
                }
                .bold()
                .opacity(currentArrowIndex >= recordedClips.count ? 1 : 0)
            }
            .padding()
            .background(Color(white: 0.1))
            
            // Interaction Area
            GeometryReader { geometry in
                let size = min(geometry.size.width, geometry.size.height)
                // Calculate arrow size in pixels
                // targetType.diameterCm corresponds to the full width of the view (size)
                let pixelsPerCm = size / targetType.diameterCm
                let arrowDiameterMm = AppSettings.shared.arrowDiameterMm
                let arrowDiameterPx = (arrowDiameterMm / 10.0) * pixelsPerCm
                
                ZStack {
                    // Target Face
                    TargetFaceView(type: targetType)
                        .frame(width: size, height: size)
                    
                    // Existing Hits
                    ForEach(arrowHits) { hit in
                        Circle()
                            .fill(Color.green)
                            .frame(width: arrowDiameterPx, height: arrowDiameterPx)
                            .position(
                                x: hit.x * size,
                                y: hit.y * size
                            )
                    }
                    
                    // Current Active Arrow (Draggable)
                    if currentArrowIndex < recordedClips.count {
                        // 1. Interaction Layer (Full Target Area)
                        // Define offset provided by user feedback (finger doesn't block)
                        let dragOffset: CGFloat = 60.0
                        
                        Color.clear
                            .contentShape(Rectangle())
                            .gesture(
                                DragGesture(minimumDistance: 0)
                                    .onChanged { value in
                                        // Apply offset: The intended target is ABOVE the finger
                                        let targetPoint = CGPoint(
                                            x: value.location.x,
                                            y: value.location.y - dragOffset
                                        )
                                        
                                        let normalizedX = targetPoint.x / size
                                        let normalizedY = targetPoint.y / size
                                        
                                        // Clamp to 0-1
                                        currentArrowLocation = CGPoint(
                                            x: max(0, min(1, normalizedX)),
                                            y: max(0, min(1, normalizedY))
                                        )
                                    }
                            )
                        
                        // 2. Visual Cursor (Follows state)
                        // Arrow Size Circle (Physically Accurate)
                        Circle()
                            .strokeBorder(Color.white, lineWidth: 1)
                            .background(Circle().fill(Color.black.opacity(0.5)))
                            .frame(width: arrowDiameterPx, height: arrowDiameterPx)
                            .position(
                                x: currentArrowLocation.x * size,
                                y: currentArrowLocation.y * size
                            )
                            .allowsHitTesting(false)
                        
                        // Larger Crosshair/Magnifier Indicator
                        ZStack {
                            Circle()
                                .stroke(Color.white.opacity(0.8), lineWidth: 1)
                                .frame(width: 40, height: 40)
                            
                            Path { path in
                                path.move(to: CGPoint(x: 20, y: 0))
                                path.addLine(to: CGPoint(x: 20, y: 40))
                                path.move(to: CGPoint(x: 0, y: 20))
                                path.addLine(to: CGPoint(x: 40, y: 20))
                            }
                            .stroke(Color.white.opacity(0.8), lineWidth: 1)
                        }
                        .position(
                            x: currentArrowLocation.x * size,
                            y: currentArrowLocation.y * size
                        )
                        .allowsHitTesting(false)
                    }
                }
                .frame(width: size, height: size)
                .position(x: geometry.size.width / 2, y: geometry.size.height / 2)
            }
            
            // Footer: Controls
            VStack(spacing: 20) {
                if currentArrowIndex < recordedClips.count {
                    // Current Score Preview
                    let currentScore = ScoringEngine.calculateScore(
                        normalizedPoint: currentArrowLocation,
                        targetType: targetType,
                        arrowDiameterMm: AppSettings.shared.arrowDiameterMm
                    )
                    
                    Text("Score: \(currentScore.isX ? "X" : String(currentScore.score))")
                        .font(.title2).bold()
                        .foregroundStyle(Color.yellow)
                    
                    Button {
                        confirmHit()
                    } label: {
                        Text("Next Arrow")
                            .font(.headline)
                            .foregroundStyle(.black)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.accentColor)
                            .cornerRadius(10)
                    }
                    .padding(.horizontal)
                } else {
                    Text("Scoring Complete!")
                        .font(.title3)
                        .foregroundStyle(.gray)
                }
            }
            .padding()
            .background(Color(white: 0.1))
        }
    }
    
    private func confirmHit() {
        guard currentArrowIndex < recordedClips.count else { return }
        
        let score = ScoringEngine.calculateScore(
            normalizedPoint: currentArrowLocation,
            targetType: targetType,
            arrowDiameterMm: AppSettings.shared.arrowDiameterMm
        )
        
        let newHit = ArrowHit(
            sessionId: currentClip?.sessionId ?? UUID(),
            arrowIndex: currentArrowIndex + 1,
            x: currentArrowLocation.x,
            y: currentArrowLocation.y,
            ringScore: score.score,
            isX: score.isX,
            linkedClipId: currentClip?.id
        )
        
        withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
            arrowHits.append(newHit)
            totalScore += score.score
            
            currentArrowIndex += 1
            
            // Reset cursor to center for next arrow
            currentArrowLocation = CGPoint(x: 0.5, y: 0.5)
        }
        
        if currentArrowIndex >= recordedClips.count {
            // Auto complete or wait for user to hit Done?
            // User might want to review.
            // But usually flow is sequential.
            // Let's autosave for now to match previous behavior, 
            // but the UI shows a "Done" button at top.
            // Actually, my UI code shows "Done" button enabled when finished.
            // I'll leave it to the user to tap "Done" or I can auto-trigger.
            // Let's auto-complete to reduce clicks.
            onComplete(arrowHits, totalScore)
        }
    }
}
