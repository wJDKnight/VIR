import SwiftUI

/// A measurement defined by three points: two endpoints and a vertex.
/// The angle is measured at the vertex (p2) between rays p2→p1 and p2→p3.
struct AngleMeasurement: Identifiable, Codable {
    var id = UUID()
    var p1X: CGFloat
    var p1Y: CGFloat
    var vertexX: CGFloat
    var vertexY: CGFloat
    var p3X: CGFloat
    var p3Y: CGFloat
    
    // Stored color components so each angle remembers the color it was drawn with.
    var colorR: Double
    var colorG: Double
    var colorB: Double
    var colorA: Double
    var lineWidth: CGFloat
    
    var p1: CGPoint {
        get { CGPoint(x: p1X, y: p1Y) }
        set { p1X = newValue.x; p1Y = newValue.y }
    }
    var vertex: CGPoint {
        get { CGPoint(x: vertexX, y: vertexY) }
        set { vertexX = newValue.x; vertexY = newValue.y }
    }
    var p3: CGPoint {
        get { CGPoint(x: p3X, y: p3Y) }
        set { p3X = newValue.x; p3Y = newValue.y }
    }
    
    var color: Color {
        Color(red: colorR, green: colorG, blue: colorB, opacity: colorA)
    }
    
    init(p1: CGPoint, vertex: CGPoint, p3: CGPoint, color: Color = .red, lineWidth: CGFloat = 5) {
        self.id = UUID()
        self.p1X = p1.x; self.p1Y = p1.y
        self.vertexX = vertex.x; self.vertexY = vertex.y
        self.p3X = p3.x; self.p3Y = p3.y
        self.lineWidth = lineWidth
        var r: CGFloat = 1, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 1
        UIColor(color).getRed(&r, green: &g, blue: &b, alpha: &a)
        self.colorR = Double(r)
        self.colorG = Double(g)
        self.colorB = Double(b)
        self.colorA = Double(a)
    }
    
    /// The measured angle in degrees at the vertex.
    var angleDegrees: Double {
        let v1 = CGVector(dx: p1.x - vertex.x, dy: p1.y - vertex.y)
        let v2 = CGVector(dx: p3.x - vertex.x, dy: p3.y - vertex.y)
        
        let dot = v1.dx * v2.dx + v1.dy * v2.dy
        let cross = v1.dx * v2.dy - v1.dy * v2.dx
        
        let angleRad = atan2(abs(cross), dot)
        return angleRad * 180.0 / .pi
    }
}

/// Overlay view that lets the user measure angles by tapping three points.
/// Point order: first endpoint → vertex → second endpoint.
/// The angle is displayed at the vertex with an arc indicator.
/// In eraser mode, tapping near any point of a measurement removes it.
struct AngleMeasurementOverlayView: View {
    @Binding var measurements: [AngleMeasurement]
    // currentColor/currentLineWidth are used only for the in-progress pending points preview.
    var currentColor: Color
    var currentLineWidth: CGFloat
    var isInteractive: Bool
    var isErasing: Bool
    
    /// Points being collected for the current in-progress measurement.
    @State private var pendingPoints: [CGPoint] = []
    
    var body: some View {
        ZStack {
            // Render completed measurements using each measurement's own stored color/width
            Canvas { context, _ in
                for m in measurements {
                    drawMeasurement(m, in: &context)
                }
            }
            
            // Render pending points and partial lines
            Canvas { context, _ in
                let dotRadius: CGFloat = 6
                
                for (i, pt) in pendingPoints.enumerated() {
                    // Dot
                    context.fill(
                        Path(ellipseIn: CGRect(x: pt.x - dotRadius, y: pt.y - dotRadius, width: dotRadius * 2, height: dotRadius * 2)),
                        with: .color(currentColor)
                    )
                    
                    // Label
                    let label: String
                    switch i {
                    case 0: label = "P1"
                    case 1: label = "V"
                    default: label = "P3"
                    }
                    context.draw(
                        Text(label).font(.caption.bold()).foregroundColor(currentColor),
                        at: CGPoint(x: pt.x + 12, y: pt.y - 12)
                    )
                    
                    // Line from previous point
                    if i == 1 {
                        var path = Path()
                        path.move(to: pendingPoints[0])
                        path.addLine(to: pt)
                        context.stroke(path, with: .color(currentColor.opacity(0.5)), style: StrokeStyle(lineWidth: currentLineWidth, dash: [6, 4]))
                    }
                }
            }
            
            // Eraser mode: tap near any point of a measurement to remove it
            if isErasing {
                Color.clear
                    .contentShape(Rectangle())
                    .onTapGesture { location in
                        if let idx = closestMeasurementIndex(to: location, threshold: 40) {
                            measurements.remove(at: idx)
                        }
                    }
            }
            // Draw mode: tap to collect points
            else if isInteractive {
                Color.clear
                    .contentShape(Rectangle())
                    .onTapGesture { location in
                        pendingPoints.append(location)
                        
                        if pendingPoints.count == 3 {
                            let m = AngleMeasurement(
                                p1: pendingPoints[0],
                                vertex: pendingPoints[1],
                                p3: pendingPoints[2],
                                color: currentColor,
                                lineWidth: currentLineWidth
                            )
                            measurements.append(m)
                            pendingPoints.removeAll()
                        }
                    }
            }
        }
    }
    
    /// Returns the index of the measurement with the closest point within threshold.
    private func closestMeasurementIndex(to point: CGPoint, threshold: CGFloat) -> Int? {
        var bestIdx: Int?
        var bestDist: CGFloat = threshold
        for (i, m) in measurements.enumerated() {
            for pt in [m.p1, m.vertex, m.p3] {
                let d = hypot(point.x - pt.x, point.y - pt.y)
                if d < bestDist {
                    bestDist = d
                    bestIdx = i
                }
            }
            // Also check proximity to the ray segments
            let d1 = distanceFromPoint(point, toSegmentFrom: m.vertex, to: m.p1)
            let d2 = distanceFromPoint(point, toSegmentFrom: m.vertex, to: m.p3)
            let minRayDist = min(d1, d2)
            if minRayDist < bestDist {
                bestDist = minRayDist
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
    
    private func drawMeasurement(_ m: AngleMeasurement, in context: inout GraphicsContext) {
        let dotRadius: CGFloat = 5
        
        // Draw the two rays from vertex using the measurement's own stored color/width
        var ray1 = Path()
        ray1.move(to: m.vertex)
        ray1.addLine(to: m.p1)
        context.stroke(ray1, with: .color(m.color), lineWidth: m.lineWidth)
        
        var ray2 = Path()
        ray2.move(to: m.vertex)
        ray2.addLine(to: m.p3)
        context.stroke(ray2, with: .color(m.color), lineWidth: m.lineWidth)
        
        // Draw dots at all three points
        for pt in [m.p1, m.vertex, m.p3] {
            context.fill(
                Path(ellipseIn: CGRect(x: pt.x - dotRadius, y: pt.y - dotRadius, width: dotRadius * 2, height: dotRadius * 2)),
                with: .color(m.color)
            )
        }
        
        // Draw arc at vertex
        let arcRadius: CGFloat = 30
        let startAngle = atan2(m.p1.y - m.vertex.y, m.p1.x - m.vertex.x)
        let endAngle = atan2(m.p3.y - m.vertex.y, m.p3.x - m.vertex.x)
        
        // Determine the sweep direction (always draw the smaller arc)
        var sweep = endAngle - startAngle
        if sweep > .pi { sweep -= 2 * .pi }
        if sweep < -.pi { sweep += 2 * .pi }
        let clockwise = sweep < 0
        
        var arcPath = Path()
        arcPath.addArc(
            center: m.vertex,
            radius: arcRadius,
            startAngle: Angle(radians: Double(startAngle)),
            endAngle: Angle(radians: Double(endAngle)),
            clockwise: clockwise
        )
        context.stroke(arcPath, with: .color(m.color), lineWidth: m.lineWidth * 0.7)
        
        // Draw angle label
        let midAngle = startAngle + (clockwise ? -1 : 1) * abs(sweep) / 2
        let labelRadius = arcRadius + 20
        let labelPoint = CGPoint(
            x: m.vertex.x + cos(midAngle) * labelRadius,
            y: m.vertex.y + sin(midAngle) * labelRadius
        )
        let angleText = String(format: "%.1f°", m.angleDegrees)
        context.draw(
            Text(angleText)
                .font(.system(size: 14, weight: .bold, design: .rounded))
                .foregroundColor(m.color),
            at: labelPoint
        )
    }
}

