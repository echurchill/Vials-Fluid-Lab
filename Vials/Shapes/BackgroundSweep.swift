import SwiftUI

struct BackgroundSweep: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.minX, y: rect.maxY * 0.64))
        path.addCurve(
            to: CGPoint(x: rect.maxX, y: rect.maxY * 0.36),
            control1: CGPoint(x: rect.width * 0.30, y: rect.maxY * 0.78),
            control2: CGPoint(x: rect.width * 0.68, y: rect.maxY * 0.42)
        )
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        path.closeSubpath()
        return path
    }
}
