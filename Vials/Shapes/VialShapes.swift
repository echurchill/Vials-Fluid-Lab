import SwiftUI

struct VialShape: Shape {
    let capacity: Int
    let unitHeight: CGFloat

    func path(in rect: CGRect) -> Path {
        let w = rect.width
        let h = rect.height
        let scale = unitHeight / 30
        let topY = h - 12 * scale - CGFloat(capacity) * unitHeight - 14 * scale
        let bottomCurveY = h - 34 * scale
        let bottomY = h - 4 * scale

        var path = Path()
        path.move(to: CGPoint(x: w * 0.12, y: topY))
        path.addLine(to: CGPoint(x: w * 0.88, y: topY))
        path.addLine(to: CGPoint(x: w * 0.88, y: bottomCurveY))
        path.addQuadCurve(
            to: CGPoint(x: w * 0.50, y: bottomY),
            control: CGPoint(x: w * 0.86, y: bottomY)
        )
        path.addQuadCurve(
            to: CGPoint(x: w * 0.12, y: bottomCurveY),
            control: CGPoint(x: w * 0.14, y: bottomY)
        )
        path.addLine(to: CGPoint(x: w * 0.12, y: topY))
        path.closeSubpath()
        return path
    }
}

struct VialTopRimShape: Shape {
    let capacity: Int
    let unitHeight: CGFloat

    func path(in rect: CGRect) -> Path {
        let w = rect.width
        let h = rect.height
        let scale = unitHeight / 30
        let topY = h - 12 * scale - CGFloat(capacity) * unitHeight - 14 * scale

        var path = Path()
        path.move(to: CGPoint(x: w * 0.12, y: topY))
        path.addLine(to: CGPoint(x: w * 0.88, y: topY))
        return path
    }
}

struct VialInteriorShape: Shape {
    let capacity: Int
    let unitHeight: CGFloat

    func path(in rect: CGRect) -> Path {
        let w = rect.width
        let h = rect.height
        let scale = unitHeight / 30
        let topY = h - 12 * scale - CGFloat(capacity) * unitHeight
        let bottomCurveY = h - 30 * scale
        let bottomY = h - 12 * scale

        var path = Path()
        path.move(to: CGPoint(x: w * 0.18, y: topY))
        path.addLine(to: CGPoint(x: w * 0.82, y: topY))
        path.addLine(to: CGPoint(x: w * 0.82, y: bottomCurveY))
        path.addQuadCurve(
            to: CGPoint(x: w * 0.50, y: bottomY),
            control: CGPoint(x: w * 0.82, y: bottomY)
        )
        path.addQuadCurve(
            to: CGPoint(x: w * 0.18, y: bottomCurveY),
            control: CGPoint(x: w * 0.18, y: bottomY)
        )
        path.addLine(to: CGPoint(x: w * 0.18, y: topY))
        path.closeSubpath()
        return path
    }
}
