import SwiftUI

struct HintSearchStatusView: View {
    var body: some View {
        HStack(spacing: 8) {
            ProgressView()
                .controlSize(.small)
                .tint(.cyan)
            Text("Finding a route…")
                .font(.system(size: 14, weight: .bold, design: .rounded))
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 14)
        .padding(.vertical, 9)
        .background(.black.opacity(0.34), in: Capsule())
        .overlay {
            Capsule()
                .stroke(.cyan.opacity(0.28), lineWidth: 1)
        }
        .accessibilityLabel("Finding a route")
    }
}

struct HintMovePromptView: View {
    let text: String
    let dismissAction: () -> Void

    var body: some View {
        HStack(spacing: 9) {
            Image(systemName: "sparkles")
                .foregroundStyle(.cyan)
            Text(text)
                .font(.system(size: 14, weight: .bold, design: .rounded))
            Button(action: dismissAction) {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(.white.opacity(0.68))
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Dismiss hint")
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 14)
        .padding(.vertical, 9)
        .background(.black.opacity(0.42), in: Capsule())
        .overlay {
            Capsule()
                .stroke(.white.opacity(0.14), lineWidth: 1)
        }
    }
}

struct HintArcView: View {
    let source: CGPoint
    let destination: CGPoint

    @State private var dashPhase: CGFloat = 0

    var body: some View {
        ZStack {
            path
                .stroke(.cyan.opacity(0.34), lineWidth: 6)
                .blur(radius: 5)

            path
                .stroke(
                    LinearGradient(
                        colors: [.cyan, .yellow],
                        startPoint: .leading,
                        endPoint: .trailing
                    ),
                    style: StrokeStyle(lineWidth: 2.4, lineCap: .round, dash: [5, 7], dashPhase: dashPhase)
                )

            Image(systemName: "drop.fill")
                .font(.system(size: 16, weight: .bold))
                .foregroundStyle(.cyan)
                .shadow(color: .cyan.opacity(0.6), radius: 5)
                .position(dropPosition)
        }
        .onAppear {
            dashPhase = 0
            withAnimation(.linear(duration: 0.85).repeatForever(autoreverses: false)) {
                dashPhase = -24
            }
        }
        .accessibilityHidden(true)
    }

    private var path: Path {
        Path { path in
            path.move(to: source)
            path.addQuadCurve(to: destination, control: controlPoint)
        }
    }

    private var controlPoint: CGPoint {
        let arcHeight = max(28, min(100, abs(destination.x - source.x) * 0.28 + 20))
        return CGPoint(
            x: (source.x + destination.x) / 2,
            y: min(source.y, destination.y) - arcHeight
        )
    }

    private var dropPosition: CGPoint {
        let t: CGFloat = 0.5
        let inverseT = 1 - t
        return CGPoint(
            x: inverseT * inverseT * source.x + 2 * inverseT * t * controlPoint.x + t * t * destination.x,
            y: inverseT * inverseT * source.y + 2 * inverseT * t * controlPoint.y + t * t * destination.y
        )
    }
}

struct DeadEndRecoveryView: View {
    let undoCount: Int?
    let undoAction: () -> Void
    let restartAction: () -> Void
    let dismissAction: () -> Void

    var body: some View {
        ZStack {
            Color.black.opacity(0.52)
                .ignoresSafeArea()

            VStack(spacing: 16) {
                Image(systemName: "arrow.triangle.turn.up.right.diamond.fill")
                    .font(.system(size: 31, weight: .bold))
                    .foregroundStyle(.cyan)

                Text("No route from here")
                    .font(.system(size: 23, weight: .black, design: .rounded))

                Text("This position cannot be completed. You can return to a solvable point or restart the level.")
                    .font(.system(size: 15, weight: .medium, design: .rounded))
                    .foregroundStyle(.white.opacity(0.68))
                    .multilineTextAlignment(.center)

                if let undoCount {
                    Button(action: undoAction) {
                        Label(undoLabel(for: undoCount), systemImage: "arrow.uturn.backward")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(HintRecoveryButtonStyle(fill: .cyan.opacity(0.86)))
                }

                Button(action: restartAction) {
                    Label("Restart level", systemImage: "arrow.counterclockwise")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(HintRecoveryButtonStyle(fill: .white.opacity(0.12)))

                Button("Keep playing", action: dismissAction)
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .foregroundStyle(.white.opacity(0.68))
            }
            .padding(24)
            .frame(maxWidth: 330)
            .background(.indigo.opacity(0.26), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke(.white.opacity(0.16), lineWidth: 1)
            }
            .shadow(color: .black.opacity(0.3), radius: 26, y: 12)
            .padding(24)
        }
    }

    private func undoLabel(for count: Int) -> String {
        "Undo \(count) \(count == 1 ? "step" : "steps")"
    }
}

private struct HintRecoveryButtonStyle: ButtonStyle {
    let fill: Color

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 15, weight: .black, design: .rounded))
            .foregroundStyle(.white)
            .padding(.vertical, 12)
            .padding(.horizontal, 14)
            .background(fill.opacity(configuration.isPressed ? 0.72 : 1), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
    }
}
