import SwiftUI

struct TargetFaceView: View {
    let type: TargetFaceType
    
    var body: some View {
        switch type {
        case .vegas3Spot:
            // Vegas 3-Spot Layout (Triangular)
            ZStack {
                Color(red: 0.95, green: 0.95, blue: 0.9) // Background paper color
                
                // Triangle formation coordinates (approximate relative offsets)
                // The total view size is implicitly defined by the container using this View.
                // We'll use GeometryReader to scale appropriately.
                GeometryReader { geometry in
                    let size = min(geometry.size.width, geometry.size.height)
                    let spotSize = size * 0.45 // Each spot is roughly 45% of total width
                    let offset = size * 0.25
                    let centerX = geometry.size.width / 2
                    let centerY = geometry.size.height / 2
                    
                    // Top Spot
                    SingleTargetFace(rings: vegasRings)
                        .frame(width: spotSize, height: spotSize)
                        .position(x: centerX, y: centerY - offset)
                    
                    // Bottom Left
                    SingleTargetFace(rings: vegasRings)
                        .frame(width: spotSize, height: spotSize)
                        .position(x: centerX - offset * 0.8, y: centerY + offset * 0.8)
                    
                    // Bottom Right
                    SingleTargetFace(rings: vegasRings)
                        .frame(width: spotSize, height: spotSize)
                        .position(x: centerX + offset * 0.8, y: centerY + offset * 0.8)
                }
            }
            .aspectRatio(1, contentMode: .fit)
            
        case .wa122, .wa80, .wa40:
            // Standard Single Spot
            SingleTargetFace(rings: standardWARings)
        }
    }
    
    // MARK: - Ring Definitions
    
    struct RingData: Identifiable {
        let id = UUID()
        let score: Int
        let color: Color
        let borderColor: Color
        var isX: Bool = false
    }
    
    // WA Standard Colors
    private let standardWARings: [RingData] = [
        RingData(score: 1, color: .white, borderColor: .black),
        RingData(score: 2, color: .white, borderColor: .black),
        RingData(score: 3, color: .black, borderColor: .white),
        RingData(score: 4, color: .black, borderColor: .white),
        RingData(score: 5, color: .blue, borderColor: .black),
        RingData(score: 6, color: .blue, borderColor: .black),
        RingData(score: 7, color: .red, borderColor: .black),
        RingData(score: 8, color: .red, borderColor: .black),
        RingData(score: 9, color: .yellow, borderColor: .black),
        RingData(score: 10, color: .yellow, borderColor: .black)
    ]
    
    // Vegas uses only 6 through 10
    private let vegasRings: [RingData] = [
        RingData(score: 6, color: .blue, borderColor: .black),
        RingData(score: 7, color: .red, borderColor: .black),
        RingData(score: 8, color: .red, borderColor: .black),
        RingData(score: 9, color: .yellow, borderColor: .black),
        RingData(score: 10, color: .yellow, borderColor: .black)
    ]
}

struct SingleTargetFace: View {
    let rings: [TargetFaceView.RingData]
    
    var body: some View {
        GeometryReader { geometry in
            let baseDiameter = min(geometry.size.width, geometry.size.height)
            
            ZStack {
                ForEach(rings) { ring in
                    // Simplified: Each zone is 1/10th of total size.
                    // Ring 1 (outermost) = 10 units wide. Ring 10 = 1 unit wide.
                    
                    let ringSize = (baseDiameter / 10.0) * CGFloat(11 - ring.score)
                    
                    Circle()
                        .fill(ring.color)
                        .frame(width: ringSize, height: ringSize)
                        .overlay(
                            Circle()
                                .stroke(ring.borderColor, lineWidth: 1)
                        )
                    
                    // Add "X" ring for the center (Score 10)
                    if ring.score == 10 {
                        let xRingSize = ringSize / 2.0 // X-ring is half the 10-ring
                        Circle()
                            .stroke(Color.black.opacity(0.5), lineWidth: 0.5)
                            .frame(width: xRingSize, height: xRingSize)
                        
                        Text("+") // Center cross
                            .font(.system(size: xRingSize * 0.5))
                            .foregroundColor(.black)
                    }
                }
            }
            .position(x: geometry.size.width / 2, y: geometry.size.height / 2)
        }
    }
}

#Preview {
    TargetFaceView(type: .vegas3Spot)
        .frame(width: 300, height: 300)
}
