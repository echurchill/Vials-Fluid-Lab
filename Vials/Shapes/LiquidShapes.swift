import SwiftUI

struct UnevenWave: Shape {
    let amplitude: CGFloat
    let phase: CGFloat

    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.minX, y: rect.midY))

        for x in stride(from: rect.minX, through: rect.maxX, by: 3) {
            let relative = (x / max(rect.width, 1)) * .pi * 2
            let y = rect.midY + sin(relative + phase) * amplitude
            path.addLine(to: CGPoint(x: x, y: y))
        }

        path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.minY))
        path.closeSubpath()
        return path
    }
}
