import SwiftUI

struct RoundedCupShape: Shape {
    let unitHeight: CGFloat

    func path(in rect: CGRect) -> Path {
        let w = rect.width
        let h = rect.height
        let scale = unitHeight / 30
        let topY = h - unitHeight - 20 * scale
        let bottomCurveY = h - 34 * scale
        let bottomY = h - 4 * scale

        var path = Path()
        path.move(to: CGPoint(x: w * 0.12, y: topY))
        path.addLine(to: CGPoint(x: w * 0.12, y: bottomCurveY))
        path.addQuadCurve(
            to: CGPoint(x: w * 0.50, y: bottomY),
            control: CGPoint(x: w * 0.14, y: bottomY)
        )
        path.addQuadCurve(
            to: CGPoint(x: w * 0.88, y: bottomCurveY),
            control: CGPoint(x: w * 0.86, y: bottomY)
        )
        path.addLine(to: CGPoint(x: w * 0.88, y: topY))
        path.addLine(to: CGPoint(x: w * 0.12, y: topY))
        path.closeSubpath()
        return path
    }
}

struct CupTopRimShape: Shape {
    let unitHeight: CGFloat

    func path(in rect: CGRect) -> Path {
        let w = rect.width
        let h = rect.height
        let scale = unitHeight / 30
        let topY = h - unitHeight - 20 * scale

        var path = Path()
        path.move(to: CGPoint(x: w * 0.12, y: topY))
        path.addLine(to: CGPoint(x: w * 0.88, y: topY))
        return path
    }
}

struct RoundedCupInteriorShape: Shape {
    let unitHeight: CGFloat

    func path(in rect: CGRect) -> Path {
        let w = rect.width
        let h = rect.height
        let scale = unitHeight / 30
        let topY = h - unitHeight - 12 * scale
        let bottomCurveY = h - 30 * scale
        let bottomY = h - 12 * scale

        var path = Path()
        path.move(to: CGPoint(x: w * 0.18, y: topY))
        path.addLine(to: CGPoint(x: w * 0.18, y: bottomCurveY))
        path.addQuadCurve(
            to: CGPoint(x: w * 0.50, y: bottomY),
            control: CGPoint(x: w * 0.18, y: bottomY)
        )
        path.addQuadCurve(
            to: CGPoint(x: w * 0.82, y: bottomCurveY),
            control: CGPoint(x: w * 0.82, y: bottomY)
        )
        path.addLine(to: CGPoint(x: w * 0.82, y: topY))
        path.addLine(to: CGPoint(x: w * 0.18, y: topY))
        path.closeSubpath()
        return path
    }
}

struct CupHandleShape: Shape {
    let unitHeight: CGFloat

    func path(in rect: CGRect) -> Path {
        let w = rect.width
        let h = rect.height
        let scale = unitHeight / 30
        let topY = h - unitHeight - 14 * scale
        let bottomY = h - 34 * scale

        var path = Path()
        path.move(to: CGPoint(x: w * 0.91, y: topY))
        path.addCurve(
            to: CGPoint(x: w * 0.91, y: bottomY),
            control1: CGPoint(x: w * 1.12, y: topY),
            control2: CGPoint(x: w * 1.12, y: bottomY)
        )
        return path
    }
}
