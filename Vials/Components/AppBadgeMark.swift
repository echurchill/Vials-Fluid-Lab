import SwiftUI

struct AppBadgeMark: View {
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            Color(red: 0.13, green: 0.12, blue: 0.34),
                            Color(red: 0.04, green: 0.07, blue: 0.18)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .overlay {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .stroke(.white.opacity(0.16), lineWidth: 1)
                }

            HStack(spacing: -3) {
                MiniBeakerIcon(colors: [
                    Color(red: 0.96, green: 0.34, blue: 0.07),
                    Color(red: 0.05, green: 0.58, blue: 0.86)
                ])
                .frame(width: 23, height: 31)

                MiniBeakerIcon(colors: [
                    Color(red: 0.00, green: 0.36, blue: 0.18),
                    Color(red: 1.00, green: 0.72, blue: 0.08)
                ])
                .frame(width: 23, height: 31)
            }
            .offset(y: 4)

            Image(systemName: "drop.fill")
                .font(.system(size: 13, weight: .black))
                .foregroundStyle(Color(red: 0.14, green: 0.78, blue: 1.00))
                .shadow(color: .cyan.opacity(0.45), radius: 6)
                .offset(y: -12)
        }
        .accessibilityHidden(true)
    }
}

struct MiniBeakerIcon: View {
    let colors: [Color]

    init(colors: [Color] = [
        Color(red: 0.96, green: 0.34, blue: 0.07),
        Color(red: 0.05, green: 0.58, blue: 0.86)
    ]) {
        self.colors = colors
    }

    var body: some View {
        ZStack {
            MiniBeakerShape()
                .fill(.white.opacity(0.05))

            VStack(spacing: 0) {
                ForEach(Array(colors.enumerated()), id: \.offset) { _, color in
                    color
                }
            }
            .clipShape(MiniBeakerInteriorShape())

            MiniBeakerShape()
                .stroke(
                    LinearGradient(
                        colors: [.white.opacity(0.42), .indigo.opacity(0.78), .white.opacity(0.16)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 3
                )

            MiniBeakerRimShape()
                .stroke(.white.opacity(0.28), style: StrokeStyle(lineWidth: 3, lineCap: .round))
        }
    }
}

struct MiniBeakerShape: Shape {
    func path(in rect: CGRect) -> Path {
        let w = rect.width
        let h = rect.height
        let topY = h * 0.07
        let bottomCurveY = h * 0.76
        let bottomY = h * 0.94

        var path = Path()
        path.move(to: CGPoint(x: w * 0.12, y: topY))
        path.addLine(to: CGPoint(x: w * 0.88, y: topY))
        path.addLine(to: CGPoint(x: w * 0.88, y: bottomCurveY))
        path.addQuadCurve(to: CGPoint(x: w * 0.50, y: bottomY), control: CGPoint(x: w * 0.86, y: bottomY))
        path.addQuadCurve(to: CGPoint(x: w * 0.12, y: bottomCurveY), control: CGPoint(x: w * 0.14, y: bottomY))
        path.closeSubpath()
        return path
    }
}

struct MiniBeakerInteriorShape: Shape {
    func path(in rect: CGRect) -> Path {
        let w = rect.width
        let h = rect.height
        let topY = h * 0.28
        let bottomCurveY = h * 0.74
        let bottomY = h * 0.88

        var path = Path()
        path.move(to: CGPoint(x: w * 0.20, y: topY))
        path.addLine(to: CGPoint(x: w * 0.80, y: topY))
        path.addLine(to: CGPoint(x: w * 0.80, y: bottomCurveY))
        path.addQuadCurve(to: CGPoint(x: w * 0.50, y: bottomY), control: CGPoint(x: w * 0.80, y: bottomY))
        path.addQuadCurve(to: CGPoint(x: w * 0.20, y: bottomCurveY), control: CGPoint(x: w * 0.20, y: bottomY))
        path.closeSubpath()
        return path
    }
}

struct MiniBeakerRimShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.width * 0.12, y: rect.height * 0.07))
        path.addLine(to: CGPoint(x: rect.width * 0.88, y: rect.height * 0.07))
        return path
    }
}
