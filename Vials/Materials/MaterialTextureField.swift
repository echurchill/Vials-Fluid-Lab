import SwiftUI

struct MaterialTextureField: View {
    let fluid: Fluid
    let seed: Int
    let density: Int

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                switch fluid.material.kind {
                case .clear:
                    ClearFluidHighlights(seed: seed)
                        .foregroundStyle(.white.opacity(0.17))
                case .fizzy:
                    BubbleField(seed: seed, count: fluid.material.particleCount + density)
                        .foregroundStyle(.white.opacity(0.30))
                case .sparkling:
                    SparkleField(seed: seed)
                        .foregroundStyle(.white.opacity(0.38))
                case .creamy:
                    CloudyMaterialField(seed: seed, color: fluid.shine.opacity(0.24))
                case .dense:
                    SedimentField(seed: seed, count: fluid.material.particleCount + density)
                        .foregroundStyle(.black.opacity(0.22))
                case .glowing:
                    GlowMaterialField(color: fluid.shine.opacity(0.34))
                    SparkleField(seed: seed)
                        .foregroundStyle(.white.opacity(0.20))
                case .iridescent:
                    IridescentSheen(seed: seed)
                    SparkleField(seed: seed)
                        .foregroundStyle(.white.opacity(0.24))
                }
            }
            .frame(width: proxy.size.width, height: proxy.size.height)
        }
    }
}

struct BubbleField: View {
    let seed: Int
    let count: Int

    private var points: [CGPoint] {
        (0..<count).map { offset in
            let x = CGFloat((offset * 31 + seed * 19) % 100) / 100
            let y = CGFloat((offset * 43 + seed * 13) % 100) / 100
            return CGPoint(x: x, y: y)
        }
    }

    var body: some View {
        GeometryReader { proxy in
            ForEach(Array(points.enumerated()), id: \.offset) { offset, point in
                Circle()
                    .stroke(lineWidth: 1)
                    .frame(width: CGFloat(3 + offset % 4), height: CGFloat(3 + offset % 4))
                    .position(x: point.x * proxy.size.width, y: point.y * proxy.size.height)
            }
        }
    }
}

struct ClearFluidHighlights: View {
    let seed: Int

    var body: some View {
        GeometryReader { proxy in
            ForEach(0..<4, id: \.self) { offset in
                Capsule()
                    .frame(width: proxy.size.width * 0.28, height: 1.5)
                    .rotationEffect(.degrees(Double((seed + offset) % 2 == 0 ? -8 : 7)))
                    .position(
                        x: proxy.size.width * CGFloat(0.24 + Double((offset * 23 + seed * 7) % 42) / 100),
                        y: proxy.size.height * CGFloat(0.18 + Double((offset * 29 + seed * 11) % 64) / 100)
                    )
            }
        }
    }
}

struct CloudyMaterialField: View {
    let seed: Int
    let color: Color

    var body: some View {
        GeometryReader { proxy in
            ForEach(0..<4, id: \.self) { offset in
                Capsule()
                    .fill(color)
                    .frame(width: proxy.size.width * 0.66, height: 7)
                    .blur(radius: 5)
                    .rotationEffect(.degrees(Double((offset + seed) % 2 == 0 ? -5 : 4)))
                    .position(
                        x: proxy.size.width * CGFloat(0.40 + Double((offset * 17 + seed * 5) % 24) / 100),
                        y: proxy.size.height * CGFloat(0.18 + Double((offset * 31 + seed * 9) % 64) / 100)
                    )
            }
        }
    }
}

struct SedimentField: View {
    let seed: Int
    let count: Int

    private var points: [CGPoint] {
        (0..<count).map { offset in
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

struct GlowMaterialField: View {
    let color: Color

    var body: some View {
        GeometryReader { proxy in
            Ellipse()
                .fill(color)
                .frame(width: proxy.size.width * 0.95, height: proxy.size.height * 0.58)
                .blur(radius: 8)
                .position(x: proxy.size.width * 0.52, y: proxy.size.height * 0.48)
        }
    }
}

struct IridescentSheen: View {
    let seed: Int

    var body: some View {
        GeometryReader { proxy in
            LinearGradient(
                colors: [
                    .white.opacity(0.00),
                    .white.opacity(0.20),
                    Color(red: 0.30, green: 0.92, blue: 1.00).opacity(0.18),
                    .white.opacity(0.00)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .frame(width: proxy.size.width * 1.4, height: proxy.size.height * 1.4)
            .rotationEffect(.degrees(Double(seed % 3) * 8 - 8))
            .offset(x: -proxy.size.width * 0.20, y: -proxy.size.height * 0.20)
        }
    }
}
