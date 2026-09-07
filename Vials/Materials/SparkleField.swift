import SwiftUI

struct SparkleField: View {
    let seed: Int

    private var points: [CGPoint] {
        (0..<8).map { offset in
            let x = CGFloat((offset * 29 + seed * 17) % 100) / 100
            let y = CGFloat((offset * 47 + seed * 11) % 100) / 100
            return CGPoint(x: x, y: y)
        }
    }

    var body: some View {
        GeometryReader { proxy in
            ForEach(Array(points.enumerated()), id: \.offset) { _, point in
                Capsule()
                    .frame(width: 3, height: 1.5)
                    .rotationEffect(.degrees(Double(point.x * 130)))
                    .position(x: point.x * proxy.size.width, y: point.y * proxy.size.height)
            }
        }
    }
}
