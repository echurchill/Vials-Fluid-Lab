import SwiftUI

struct LiquidParticleField: View {
    let seed: Int

    private var points: [CGPoint] {
        (0..<7).map { offset in
            let x = CGFloat((offset * 37 + seed * 23) % 100) / 100
            let y = CGFloat((offset * 19 + seed * 31) % 100) / 100
            return CGPoint(x: x, y: y)
        }
    }

    var body: some View {
        GeometryReader { proxy in
            ForEach(Array(points.enumerated()), id: \.offset) { offset, point in
                Circle()
                    .frame(width: CGFloat(2 + offset % 3), height: CGFloat(2 + offset % 3))
                    .position(x: point.x * proxy.size.width, y: point.y * proxy.size.height)
            }
        }
    }
}
