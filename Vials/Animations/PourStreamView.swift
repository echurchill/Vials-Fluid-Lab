import SwiftUI

struct PourStreamView: View {
    let source: CGPoint
    let destination: CGPoint
    let fluid: Fluid
    let amount: Int

    @State private var progress: CGFloat = 0
    @State private var pulse: CGFloat = 0.7

    var body: some View {
        let material = fluid.material
        let width = material.streamWidth + CGFloat(max(0, amount - 1)) * 1.2
        let control = CGPoint(
            x: (source.x + destination.x) / 2,
            y: min(source.y, destination.y) - arcLift(for: material, width: width)
        )
        let visibleRange = streamRange(for: progress)
        let streamOpacity = streamOpacity(for: progress)

        ZStack {
            PourSplashView(destination: destination, fluid: fluid, progress: progress, amount: amount)

            Path { path in
                path.move(to: source)
                path.addQuadCurve(to: destination, control: control)
            }
            .trim(from: visibleRange.lowerBound, to: visibleRange.upperBound)
            .stroke(
                fluid.color.opacity(glowOpacity(for: material)),
                style: StrokeStyle(lineWidth: width * 2.5, lineCap: .round)
            )
            .blur(radius: width * 0.55)
            .opacity(streamOpacity)

            Path { path in
                path.move(to: source)
                path.addQuadCurve(to: destination, control: control)
            }
            .trim(from: visibleRange.lowerBound, to: visibleRange.upperBound)
            .stroke(
                LinearGradient(
                    colors: streamColors(for: material),
                    startPoint: .top,
                    endPoint: .bottom
                ),
                style: StrokeStyle(lineWidth: width + pulse, lineCap: .round)
            )
            .shadow(color: fluid.color.opacity(shadowOpacity(for: material)), radius: 8)
            .opacity(streamOpacity)

            PourDropletField(source: source, control: control, destination: destination, fluid: fluid, progress: progress)
        }
        .onAppear {
            withAnimation(.timingCurve(0.18, 0.78, 0.24, 1.0, duration: max(0.30, material.pourDuration))) {
                progress = 1
            }

            withAnimation(.easeInOut(duration: 0.18).repeatCount(6, autoreverses: true)) {
                pulse = max(0.6, CGFloat(amount) * 0.35)
            }
        }
    }

    private func arcLift(for material: FluidMaterial, width: CGFloat) -> CGFloat {
        let base = 30 + width

        switch material.kind {
        case .dense, .creamy:
            return base * 0.72
        case .clear, .sparkling:
            return base * 1.10
        default:
            return base
        }
    }

    private func streamRange(for progress: CGFloat) -> ClosedRange<CGFloat> {
        let head = min(1, max(0, progress * 1.24))
        let tailDelay: CGFloat = amount > 1 ? 0.18 : 0.28
        let tail = max(0, (progress - tailDelay) / max(0.001, 1 - tailDelay))
        return tail...max(tail, head)
    }

    private func streamOpacity(for progress: CGFloat) -> Double {
        let fadeIn = min(1, Double(progress / 0.12))
        let fadeOut = min(1, Double((1 - progress) / 0.10))
        return max(0, min(fadeIn, fadeOut + 0.08))
    }

    private func streamColors(for material: FluidMaterial) -> [Color] {
        switch material.kind {
        case .clear:
            [fluid.shine.opacity(0.70), fluid.color.opacity(0.82), fluid.color.opacity(0.66)]
        case .creamy:
            [fluid.shine.opacity(0.96), fluid.color, fluid.color.opacity(0.94)]
        case .dense:
            [fluid.shine.opacity(0.58), fluid.color, fluid.color.opacity(0.90)]
        case .glowing:
            [fluid.shine, fluid.color, fluid.shine.opacity(0.70)]
        case .iridescent:
            [fluid.shine, Color.white.opacity(0.40), fluid.color.opacity(0.86)]
        default:
            [fluid.shine.opacity(0.72), fluid.color.opacity(0.96), fluid.color]
        }
    }

    private func glowOpacity(for material: FluidMaterial) -> Double {
        switch material.kind {
        case .glowing:
            0.38
        case .iridescent:
            0.22
        default:
            0.14
        }
    }

    private func shadowOpacity(for material: FluidMaterial) -> Double {
        switch material.kind {
        case .clear:
            0.32
        case .glowing:
            0.62
        default:
            0.46
        }
    }
}

struct PourSplashView: View {
    let destination: CGPoint
    let fluid: Fluid
    let progress: CGFloat
    let amount: Int

    var body: some View {
        ZStack {
            Ellipse()
                .stroke(fluid.shine.opacity(0.34), lineWidth: 2)
                .frame(width: splashWidth, height: splashHeight)
                .scaleEffect(progress > 0.72 ? 1 : 0.45)
                .opacity(progress > 0.38 && progress < 0.98 ? 0.72 : 0)

            ForEach(0..<min(10, fluid.material.particleCount), id: \.self) { index in
                Circle()
                    .fill(fluid.shine.opacity(0.52))
                    .frame(width: CGFloat(2 + index % 3), height: CGFloat(2 + index % 3))
                    .offset(splashOffset(for: index))
                    .opacity(progress > 0.52 && progress < 0.98 ? 0.62 : 0)
            }
        }
        .position(destination)
        .animation(.easeOut(duration: 0.22), value: progress)
    }

    private var splashWidth: CGFloat {
        20 + CGFloat(amount) * 5
    }

    private var splashHeight: CGFloat {
        6 + CGFloat(amount) * 1.6
    }

    private func splashOffset(for index: Int) -> CGSize {
        let spread = CGFloat(8 + amount * 2)
        let x = CGFloat((index * 11) % 19 - 9) / 9 * spread
        let y = CGFloat((index * 7) % 9 - 4) / 4 * 4
        return CGSize(width: x, height: y)
    }
}

struct PourDropletField: View {
    let source: CGPoint
    let control: CGPoint
    let destination: CGPoint
    let fluid: Fluid
    let progress: CGFloat

    var body: some View {
        ForEach(0..<fluid.material.particleCount, id: \.self) { index in
            let pointProgress = min(max(progress - CGFloat(index) * 0.055, 0), 1)
            let point = quadraticPoint(from: source, control: control, to: destination, progress: pointProgress)
            let offset = dropletOffset(for: index)

            droplet(for: index)
                .position(x: point.x + offset.width, y: point.y + offset.height)
                .opacity(pointProgress > 0.08 && pointProgress < 0.98 ? dropletOpacity : 0)
        }
    }

    @ViewBuilder
    private func droplet(for index: Int) -> some View {
        switch fluid.material.kind {
        case .fizzy:
            Circle()
                .stroke(.white.opacity(0.64), lineWidth: 1)
                .background(Circle().fill(fluid.color.opacity(0.18)))
                .frame(width: CGFloat(4 + index % 4), height: CGFloat(4 + index % 4))
        case .sparkling, .iridescent:
            Capsule()
                .fill(.white.opacity(0.70))
                .frame(width: CGFloat(5 + index % 3), height: 2)
                .rotationEffect(.degrees(Double(index * 29)))
        case .creamy, .dense:
            Circle()
                .fill(fluid.color.opacity(0.78))
                .frame(width: CGFloat(4 + index % 3), height: CGFloat(4 + index % 3))
        default:
            Circle()
                .fill(fluid.color.opacity(0.72))
                .frame(width: CGFloat(3 + index % 3), height: CGFloat(3 + index % 3))
        }
    }

    private var dropletOpacity: Double {
        switch fluid.material.kind {
        case .creamy, .dense:
            0.58
        case .clear:
            0.44
        default:
            0.82
        }
    }

    private func quadraticPoint(from start: CGPoint, control: CGPoint, to end: CGPoint, progress: CGFloat) -> CGPoint {
        let t = progress
        let inverse = 1 - t
        return CGPoint(
            x: inverse * inverse * start.x + 2 * inverse * t * control.x + t * t * end.x,
            y: inverse * inverse * start.y + 2 * inverse * t * control.y + t * t * end.y
        )
    }

    private func dropletOffset(for index: Int) -> CGSize {
        let x = CGFloat((index * 9) % 13) - 6
        let y = CGFloat((index * 7) % 11) - 5
        return CGSize(width: x, height: y)
    }
}
