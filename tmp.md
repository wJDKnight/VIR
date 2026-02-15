The **Vegas 3-Spot** and **World Archery (WA)** target faces are defined by strict international and national standards. Below are the precise specifications for the target types you requested, followed by the best approach to generating them programmatically on iOS.

### 1. Archery Target Face Standards

#### **World Archery (WA) Standard Faces**
All WA targets (122cm, 80cm, 60cm, 40cm) follow the same **geometric ratio**. They consist of 10 scoring zones (circles) of equal width.
*   **Colors:**
    *   **Gold (Yellow):** Zones 10, 9
    *   **Red:** Zones 8, 7
    *   **Blue (Light Blue):** Zones 6, 5
    *   **Black:** Zones 4, 3
    *   **White:** Zones 2, 1
*   **Ring Width Calculation:** Target Diameter ÷ 20 = Width of one scoring zone.

| Target Face  | 1-Ring Width | 10-Ring Diameter | Inner 10 (X) Diameter | Notes                                |
| :----------- | :----------- | :--------------- | :-------------------- | :----------------------------------- |
| **WA 122cm** | 6.1 cm       | 12.2 cm          | 6.1 cm                | Standard for Outdoor Recurve (70m).  |
| **WA 80cm**  | 4.0 cm       | 8.0 cm           | 4.0 cm                | Standard for Outdoor Compound (50m). |
| **WA 40cm**  | 2.0 cm       | 4.0 cm           | 2.0 cm                | Standard for Indoor (18m).           |

#### **Vegas 3-Spot Target Face**
The "Vegas" face is a specific variation used primarily in NFAA and "The Vegas Shoot" indoor tournaments.
*   **Geometry:** It is geometrically identical to the **WA 40cm** face but includes **only the 6 through 10 rings**.
*   **Visual Dimensions (Per Spot):**
    *   **Diameter of Spot:** 20 cm (The edge of the 6-ring).
    *   **10-Ring (Gold):** 4.0 cm diameter.
    *   **9-Ring (Gold):** 8.0 cm diameter.
    *   **8-Ring (Red):** 12.0 cm diameter.
    *   **7-Ring (Red):** 16.0 cm diameter.
    *   **6-Ring (Blue):** 20.0 cm diameter.
    *   **X-Ring (Inner 10):** 2.0 cm diameter.
*   **Layout:** Three spots arranged in a triangular formation (two bottom, one top) or occasionally a vertical column.
    *   **Center-to-Center Spacing:** approx. 22 cm (Standard for 40cm triple faces).
*   **Scoring Nuance:**
    *   **Championship (Pro):** The "Big 10" (4cm yellow) scores 10 points. The "Baby X" (2cm) is used for tie-breakers.
    *   **Compound (NFAA Rules/Shoot-offs):** Often only the "Baby X" counts as 10, while the rest of the yellow scores 9.

---

### 2. Generating a Virtual Target on iOS

The best way to generate these targets on an iOS device is using **SwiftUI**. It allows for resolution-independent vector graphics that look sharp on any screen size (Retina displays) and is significantly easier to maintain than older Core Graphics (`drawRect`) code.

#### **Recommended Approach: SwiftUI `ZStack` & `Shape`**
You should build the target by layering `Circle` views on top of each other, starting from the largest (1-ring or 6-ring) to the smallest (X-ring).

**Key Algorithm:**
1.  Define a base `scaleFactor` (e.g., 1 point = 1 mm).
2.  Create a struct for a `Ring` containing its diameter and color.
3.  Loop through your rings in reverse order (largest to smallest) inside a `ZStack`.

#### **Swift Code Example**
Here is a complete, copy-pasteable View component that can generate any standard WA target face.

```swift
import SwiftUI

struct ArcheryTargetView: View {
    // Enum to select target type
    enum TargetType {
        case wa122, wa80, wa40, vegas3Spot
    }
    
    let type: TargetType
    
    var body: some View {
        switch type {
        case .vegas3Spot:
            // Vegas 3-Spot Layout (Triangular)
            ZStack {
                Color.gray.opacity(0.2).ignoresSafeArea() // Background paper color
                
                // Triangle formation coordinates (approximate relative offsets)
                let offset: CGFloat = 110 // Represents ~11cm spacing from center
                
                // Top Spot
                TargetFace(baseDiameter: 200, rings: vegasRings)
                    .offset(y: -offset)
                
                // Bottom Left
                TargetFace(baseDiameter: 200, rings: vegasRings)
                    .offset(x: -offset, y: offset * 0.8)
                
                // Bottom Right
                TargetFace(baseDiameter: 200, rings: vegasRings)
                    .offset(x: offset, y: offset * 0.8)
            }
            .aspectRatio(1, contentMode: .fit)
            
        case .wa122, .wa80, .wa40:
            // Standard Single Spot
            TargetFace(baseDiameter: baseDiameter, rings: standardWARings)
                .padding()
        }
    }
    
    // MARK: - Dimensions
    
    private var baseDiameter: CGFloat {
        switch type {
        case .wa122: return 1220 // 122cm
        case .wa80: return 800     // 80cm
        case .wa40: return 400     // 40cm
        default: return 400
        }
    }
    
    // MARK: - Ring Definitions
    
    // Data model for a single ring
    struct RingData: Identifiable {
        let id = UUID()
        let score: Int
        let color: Color
        let borderColor: Color
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

struct TargetFace: View {
    let baseDiameter: CGFloat
    let rings: [ArcheryTargetView.RingData]
    
    var body: some View {
        GeometryReader { geometry in
            let scale = min(geometry.size.width, geometry.size.height) / baseDiameter
            
            ZStack {
                ForEach(rings) { ring in
                    // Calculate diameter for this specific ring
                    // Formula: (BaseDiameter / 10) * (11 - Score) roughly, 
                    // but accurate construction uses specific zones.
                    // Simplified: Each zone is 1/10th of total size.
                    // Ring 1 (outermost) = 10 units wide. Ring 10 = 1 unit wide.
                    
                    let ringSize = (baseDiameter / 10.0) * CGFloat(11 - ring.score) * scale
                    
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

// Preview Provider
struct ArcheryTargetView_Previews: PreviewProvider {
    static var previews: some View {
        ArcheryTargetView(type: .vegas3Spot)
            .frame(width: 300, height: 300)
    }
}
```

#### **Why this approach?**
1.  **Scalability:** The code uses a `scale` factor calculated from the parent view's size. This means the target will draw perfectly whether it's a thumbnail or a full-screen iPad view.
2.  **Accuracy:** By using the standard formula (`Diameter / 10` per zone), you respect the official World Archery ratios.
3.  **Performance:** SwiftUI handles the rendering optimization automatically.
4.  **Dark Mode Support:** You can easily tweak the `borderColor` logic to support dark mode (e.g., making the black rings have a white border, which is standard on physical targets anyway).