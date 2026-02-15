import Foundation
import CoreGraphics

struct ScoringEngine {
    
    /// Calculates the score for a given arrow hit.
    /// - Parameters:
    ///   - normalizedPoint: The hit position (0...1), where (0.5, 0.5) is center.
    ///   - targetType: The type of target face.
    ///   - arrowDiameterMm: The diameter of the arrow in millimeters.
    /// - Returns: A tuple containing (ringScore, isX).
    static func calculateScore(
        normalizedPoint: CGPoint,
        targetType: TargetFaceType,
        arrowDiameterMm: Double
    ) -> (score: Int, isX: Bool) {
        
        // Determine target center(s)
        let centers: [CGPoint]
        if targetType == .vegas3Spot {
            // Centers based on TargetFaceView layout:
            // Top: (0.5, 0.25)
            // Bottom Left: (0.3, 0.7)
            // Bottom Right: (0.7, 0.7)
            centers = [
                CGPoint(x: 0.5, y: 0.25),
                CGPoint(x: 0.3, y: 0.7),
                CGPoint(x: 0.7, y: 0.7)
            ]
        } else {
            centers = [CGPoint(x: 0.5, y: 0.5)]
        }
        
        // Find closest center
        let distFromCenterNormalized = centers.map { center in
            let dx = normalizedPoint.x - center.x
            let dy = normalizedPoint.y - center.y
            return sqrt(dx*dx + dy*dy)
        }.min() ?? 1.0
        
        // Convert normalized distance to cm
        // Note: For Vegas, the "face" diameter in logic often refers to the single spot diameter when scoring,
        // but TargetFaceType.diameterCm returns 40.0 for Vegas (the whole paper).
        // Standard Vegas spot diameter is roughly 20cm? 
        // Let's assume the normalized distance scales with the full paper size.
        let distFromCenterCm = distFromCenterNormalized * targetType.diameterCm
        
        // Convert arrow radius to cm
        let arrowRadiusCm = (arrowDiameterMm / 10.0) / 2.0
        
        // "Line Cutter" Logic:
        // The arrow scores the higher value if it touches the line.
        // This is equivalent to checking if the inner edge of the arrow (closest to center)
        // is within the outer radius of the scoring ring.
        // Inner edge distance = center-to-center distance - arrow radius
        let innerEdgeDistCm = distFromCenterCm - arrowRadiusCm
        
        // Calculate ring width
        // WA targets have 10 rings of equal width.
        // Ring 10 (Gold) diameter = TotalDiameter / 10. radius = TotalDiameter / 20.
        let ringWidthCm = targetType.diameterCm / 20.0
        
        // Check X-Ring first
        let xRingRadiusCm = targetType.xRingDiameterCm / 2.0
        if innerEdgeDistCm <= xRingRadiusCm {
            return (10, true)
        }
        
        // Iterate through rings from 10 down to 1
        for score in stride(from: 10, through: 1, by: -1) {
            // Outer radius of this scoring zone
            // Score 10 is the 1st zone from center. Score 1 is the 10th.
            // But mathematically, the radius of ring N is (11 - N) * ringWidth?
            // Wait.
            // Ring 10 radius = 1 * ringWidth
            // Ring 9 radius = 2 * ringWidth
            // ...
            // Ring 1 radius = 10 * ringWidth
            
            let ringIndexFromCenter = 11 - score // 1 for score 10, 10 for score 1
            let outerRadiusMsg = Double(ringIndexFromCenter) * ringWidthCm
            
            if innerEdgeDistCm <= outerRadiusMsg {
                // Determine valid scores for specific target types
                if targetType == .vegas3Spot && score < 6 {
                    return (0, false) // Vegas only goes down to 6
                }
                return (score, false)
            }
        }
        
        return (0, false) // Miss
    }
}
