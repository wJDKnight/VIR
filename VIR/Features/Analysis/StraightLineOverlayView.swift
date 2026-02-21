import SwiftUI

/// A line segment defined by two endpoints, with its own color and width.
struct LineSegment: Identifiable, Codable {
    var id = UUID()
    var startX: CGFloat
    var startY: CGFloat
    var endX: CGFloat
    var endY: CGFloat
    
    // Stored color components so each line remembers the color it was drawn with.
    var colorR: Double
    var colorG: Double
    var colorB: Double
    var colorA: Double
    var lineWidth: CGFloat
    
    var start: CGPoint {
        get { CGPoint(x: startX, y: startY) }
        set { startX = newValue.x; startY = newValue.y }
    }
    var end: CGPoint {
        get { CGPoint(x: endX, y: endY) }
        set { endX = newValue.x; endY = newValue.y }
    }
    
    var color: Color {
        Color(red: colorR, green: colorG, blue: colorB, opacity: colorA)
    }
    
    init(start: CGPoint, end: CGPoint, color: Color = .red, lineWidth: CGFloat = 5) {
        self.id = UUID()
        self.startX = start.x
        self.startY = start.y
        self.endX = end.x
        self.endY = end.y
        self.lineWidth = lineWidth
        var r: CGFloat = 1, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 1
        UIColor(color).getRed(&r, green: &g, blue: &b, alpha: &a)
        self.colorR = Double(r)
        self.colorG = Double(g)
        self.colorB = Double(b)
        self.colorA = Double(a)
    }
}

/// Overlay view that lets the user draw straight lines by dragging.
/// Completed lines persist on screen; an undo action removes the last one.
/// In eraser mode, tapping near a line removes it.
struct StraightLineOverlayView: View {
    @Binding var lines: [LineSegment]
    var currentColor: Color
    var currentLineWidth: CGFloat
    var isInteractive: Bool
    var isErasing: Bool
    
    @State private var activeStart: CGPoint?
    @State private var activeEnd: CGPoint?
    
    var body: some View {
        ZStack {
            // Render completed lines using each line's own stored color/width
            Canvas { context, _ in
                for line in lines {
                    var path = Path()
                    path.move(to: line.start)
                    path.addLine(to: line.end)
                    context.stroke(path, with: .color(line.color), lineWidth: line.lineWidth)
                    
                    // Draw small circles at endpoints
                    let radius: CGFloat = line.lineWidth * 1.2
                    context.fill(
                        Path(ellipseIn: CGRect(x: line.start.x - radius, y: line.start.y - radius, width: radius * 2, height: radius * 2)),
                        with: .color(line.color)
                    )
                    context.fill(
                        Path(ellipseIn: CGRect(x: line.end.x - radius, y: line.end.y - radius, width: radius * 2, height: radius * 2)),
                        with: .color(line.color)
                    )
                }
            }
            
            // Render active (in-progress) line using the current tool color
            if let start = activeStart, let end = activeEnd {
                Canvas { context, _ in
                    var path = Path()
                    path.move(to: start)
                    path.addLine(to: end)
                    context.stroke(path, with: .color(currentColor.opacity(0.7)), style: StrokeStyle(lineWidth: currentLineWidth, dash: [8, 4]))
                }
            }
            
            // Eraser mode: tap near a line to remove it
            if isErasing {
                Color.clear
                    .contentShape(Rectangle())
                    .onTapGesture { location in
                        if let idx = closestLineIndex(to: location, threshold: 30) {
                            lines.remove(at: idx)
                        }
                    }
            }
            // Draw mode: drag to create lines
            else if isInteractive {
                Color.clear
                    .contentShape(Rectangle())
                    .gesture(
                        DragGesture(minimumDistance: 5)
                            .onChanged { value in
                                if activeStart == nil {
                                    activeStart = value.startLocation
                                }
                                activeEnd = value.location
                            }
                            .onEnded { value in
                                if let start = activeStart {
                                    lines.append(LineSegment(start: start, end: value.location, color: currentColor, lineWidth: currentLineWidth))
                                }
                                activeStart = nil
                                activeEnd = nil
                            }
                    )
            }
        }
    }
    
    /// Returns the index of the closest line within the given threshold distance.
    private func closestLineIndex(to point: CGPoint, threshold: CGFloat) -> Int? {
        var bestIdx: Int?
        var bestDist: CGFloat = threshold
        for (i, line) in lines.enumerated() {
            let d = distanceFromPoint(point, toSegmentFrom: line.start, to: line.end)
            if d < bestDist {
                bestDist = d
                bestIdx = i
            }
        }
        return bestIdx
    }
    
    /// Perpendicular distance from a point to a line segment.
    private func distanceFromPoint(_ p: CGPoint, toSegmentFrom a: CGPoint, to b: CGPoint) -> CGFloat {
        let dx = b.x - a.x
        let dy = b.y - a.y
        let lengthSq = dx * dx + dy * dy
        guard lengthSq > 0 else { return hypot(p.x - a.x, p.y - a.y) }
        var t = ((p.x - a.x) * dx + (p.y - a.y) * dy) / lengthSq
        t = max(0, min(1, t))
        let projX = a.x + t * dx
        let projY = a.y + t * dy
        return hypot(p.x - projX, p.y - projY)
    }
}
