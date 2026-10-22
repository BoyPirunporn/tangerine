import CoreGraphics
import Foundation

/// Geometry of the radial menu. Angles are degrees measured clockwise from the top.
struct RadialLayout: Equatable {
    let count: Int
    let inner: CGFloat
    let outer: CGFloat
    /// Visual gap between neighbouring wedges, in points.
    var gap: CGFloat = 6
    /// Radius of the rounded corners of each wedge, in points.
    var cornerRadius: CGFloat = 20

    var sweep: Double { count > 0 ? 360 / Double(count) : 0 }

    /// Which wedge a point belongs to, or `nil` for the hub. `point` and `center` use y-down coordinates.
    func index(at point: CGPoint, center: CGPoint) -> Int? {
        guard count > 0 else { return nil }
        let dx = Double(point.x - center.x)
        let dy = Double(point.y - center.y)
        guard hypot(dx, dy) >= Double(inner) else { return nil }
        var degrees = atan2(dx, -dy) * 180 / .pi
        if degrees < 0 { degrees += 360 }
        return min(Int(degrees / sweep), count - 1)
    }

    func labelPoint(_ index: Int, center: CGPoint) -> CGPoint {
        let radius = Double(inner + outer) / 2
        return point(angle: (Double(index) + 0.5) * sweep, radius: radius, center: center)
    }

    /// A polygon that, grown outwards by the returned `cornerRadius` (stroked with a round join),
    /// gives the wedge with rounded corners and `gap` between it and its neighbours.
    /// The radius shrinks when the wedge is too narrow to hold the full one.
    func outline(_ index: Int, center: CGPoint) -> (points: [CGPoint], cornerRadius: CGFloat) {
        guard count > 1 else { return (ring(center: center), 0) }
        var radius = cornerRadius
        while radius >= 0 {
            if let points = insetPolygon(index, center: center, inset: gap / 2 + radius) {
                return (points, radius)
            }
            radius -= 2
        }
        return (insetPolygon(index, center: center, inset: 0) ?? [], 0)
    }

    /// The wedge shrunk by `inset` points from its two straight edges and both arcs.
    private func insetPolygon(_ index: Int, center: CGPoint, inset d: CGFloat) -> [CGPoint]? {
        let d = Double(d)
        let rIn = Double(inner) + d
        let rOut = Double(outer) - d
        guard rOut > rIn, rIn > d else { return nil }

        let a1 = Double(index) * sweep * .pi / 180
        let a2 = Double(index + 1) * sweep * .pi / 180
        // Unit vector along each edge, and the normal pointing into the wedge.
        let (u1x, u1y, n1x, n1y) = (sin(a1), -cos(a1), cos(a1), sin(a1))
        let (u2x, u2y, n2x, n2y) = (sin(a2), -cos(a2), -cos(a2), -sin(a2))
        let tIn = (rIn * rIn - d * d).squareRoot()
        let tOut = (rOut * rOut - d * d).squareRoot()

        func edgePoint(_ ux: Double, _ uy: Double, _ nx: Double, _ ny: Double, _ t: Double) -> (x: Double, y: Double) {
            (ux * t + nx * d, uy * t + ny * d)
        }
        func angle(of p: (x: Double, y: Double)) -> Double { atan2(p.x, -p.y) }

        let p1In = edgePoint(u1x, u1y, n1x, n1y, tIn)
        let p1Out = edgePoint(u1x, u1y, n1x, n1y, tOut)
        let p2In = edgePoint(u2x, u2y, n2x, n2y, tIn)
        let p2Out = edgePoint(u2x, u2y, n2x, n2y, tOut)

        func span(from start: Double, to end: Double) -> Double {
            var delta = end - start
            if delta < 0 { delta += 2 * .pi }
            return delta
        }
        let inSpan = span(from: angle(of: p1In), to: angle(of: p2In))
        let outSpan = span(from: angle(of: p1Out), to: angle(of: p2Out))
        let wedgeSpan = a2 - a1
        guard inSpan > 0.01, outSpan > 0.01, inSpan <= wedgeSpan + 0.001, outSpan <= wedgeSpan + 0.001 else { return nil }

        func arc(from start: Double, span: Double, radius: Double) -> [CGPoint] {
            let steps = max(2, Int(abs(span) * 180 / .pi / 2))
            return (0...steps).map { step in
                let a = start + span * Double(step) / Double(steps)
                return CGPoint(x: center.x + radius * sin(a), y: center.y - radius * cos(a))
            }
        }
        func at(_ p: (x: Double, y: Double)) -> CGPoint { CGPoint(x: center.x + p.x, y: center.y + p.y) }

        return [at(p1In), at(p1Out)]
            + arc(from: angle(of: p1Out), span: outSpan, radius: rOut)
            + [at(p2Out), at(p2In)]
            + arc(from: angle(of: p2In), span: -inSpan, radius: rIn)
    }

    /// A single wedge covers the whole circle: a plain ring.
    private func ring(center: CGPoint) -> [CGPoint] {
        let around = (0...180).map { Double($0) * 2 }
        return around.map { point(angle: $0, radius: Double(outer), center: center) }
            + around.reversed().map { point(angle: $0, radius: Double(inner), center: center) }
    }

    private func point(angle degrees: Double, radius: Double, center: CGPoint) -> CGPoint {
        let radians = degrees * .pi / 180
        return CGPoint(x: center.x + radius * sin(radians), y: center.y - radius * cos(radians))
    }
}
