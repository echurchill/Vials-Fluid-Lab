import SwiftUI

struct WinCelebrationView: View {
    let levelNumber: Int
    let moveCount: Int
    let minimumMoveCount: Int?
    let masteryTier: MasteryTier
    let bestMasteryTier: MasteryTier
    let flow: FlowState
    let wasHintAssisted: Bool
    let isFinalLevel: Bool
    let rating: LevelFeedbackRating?
    let ratingAction: (LevelFeedbackRating) -> Void
    let nextAction: () -> Void
    let replayAction: () -> Void
    let dismissAction: () -> Void

    @State private var animate = false
    @State private var shimmer = false

    var body: some View {
        ZStack {
            Color.black.opacity(0.24)
                .ignoresSafeArea()
                .onTapGesture(perform: dismissAction)

            CelebrationDropletField(animate: animate, isPerfect: isPerfectSolve)
                .allowsHitTesting(false)

            VStack(spacing: 18) {
                ZStack {
                    Circle()
                        .fill(primaryGlow.opacity(isPerfectSolve ? 0.26 : 0.16))
                        .frame(width: isPerfectSolve ? 102 : 86, height: isPerfectSolve ? 102 : 86)
                        .scaleEffect(animate ? 1.08 : 0.86)
                        .blur(radius: 2)

                    if isPerfectSolve {
                        PerfectBurstView(animate: animate)
                            .frame(width: 118, height: 118)
                    }

                    MiniBeakerIcon()
                        .frame(width: 54, height: 62)
                        .offset(y: 4)
                }

                VStack(spacing: 6) {
                    Text(title)
                        .font(.system(size: 28, weight: .black, design: .rounded))
                        .multilineTextAlignment(.center)
                    Text("\(moveCount) moves")
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                        .foregroundStyle(.white.opacity(0.68))
                        .monospacedDigit()

                    if let minimumMoveCount {
                        Text(minimumText(for: minimumMoveCount))
                            .font(.system(size: 14, weight: .heavy, design: .rounded))
                            .foregroundStyle(isPerfectSolve ? AnyShapeStyle(perfectTextStyle) : AnyShapeStyle(.white.opacity(0.48)))
                            .monospacedDigit()
                    }
                }

                VStack(spacing: 7) {
                    HStack(spacing: 7) {
                        ForEach(0..<3, id: \.self) { index in
                            Image(systemName: "drop.fill")
                                .font(.system(size: 17, weight: .black))
                                .foregroundStyle(index < masteryTier.dropletCount ? .cyan : .white.opacity(0.16))
                        }
                    }

                    Text(masteryMessage)
                        .font(.system(size: 15, weight: .black, design: .rounded))
                        .foregroundStyle(masteryTier == .top ? .yellow : .white.opacity(0.9))

                    FlowProgressView(flow: flow, isHintAssisted: wasHintAssisted)
                }

                VStack(spacing: 9) {
                    Text("How did that level feel?")
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                        .foregroundStyle(.white.opacity(0.62))

                    HStack(spacing: 14) {
                        ForEach(LevelFeedbackRating.allCases) { option in
                            CelebrationRatingButton(
                                rating: option,
                                isSelected: rating == option
                            ) {
                                ratingAction(option)
                            }
                        }
                    }
                }

                HStack(spacing: 12) {
                    CelebrationActionButton(systemName: "arrow.counterclockwise", label: "Replay", action: replayAction)

                    if !isFinalLevel {
                        CelebrationActionButton(systemName: "chevron.right", label: "Next", isPrimary: true, action: nextAction)
                    }

                    CelebrationActionButton(systemName: "xmark", label: "Close", action: dismissAction)
                }
            }
            .padding(.horizontal, 28)
            .padding(.vertical, 26)
            .frame(width: 330)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke(borderStyle, lineWidth: isPerfectSolve ? 1.5 : 1)
            }
            .shadow(color: primaryGlow.opacity(isPerfectSolve ? 0.36 : 0.20), radius: isPerfectSolve ? 34 : 26, y: 12)
            .scaleEffect(animate ? 1 : 0.94)
        }
        .onAppear {
            withAnimation(.spring(response: 0.48, dampingFraction: 0.72)) {
                animate = true
            }

            withAnimation(.easeInOut(duration: 0.95).repeatForever(autoreverses: true)) {
                shimmer = true
            }
        }
    }

    private var isPerfectSolve: Bool {
        minimumMoveCount.map { $0 == moveCount } ?? false
    }

    private var title: String {
        if isPerfectSolve {
            return "Perfect Solve"
        }

        return isFinalLevel ? "All Levels Sorted" : "Level \(levelNumber) Sorted"
    }

    private var masteryMessage: String {
        if masteryTier < bestMasteryTier {
            return "Completed · Best remains \(bestMasteryTier.label)"
        }
        return masteryTier.label
    }

    private func minimumText(for minimumMoveCount: Int) -> String {
        if isPerfectSolve {
            return "Minimum \(minimumMoveCount) moves"
        }

        return "Best known: \(minimumMoveCount)"
    }

    private var primaryGlow: Color {
        isPerfectSolve ? .yellow : .cyan
    }

    private var perfectTextStyle: LinearGradient {
        LinearGradient(
            colors: [
                Color.yellow.opacity(shimmer ? 1.0 : 0.72),
                Color.white.opacity(0.92),
                Color.orange.opacity(shimmer ? 0.78 : 1.0)
            ],
            startPoint: .leading,
            endPoint: .trailing
        )
    }

    private var borderStyle: some ShapeStyle {
        if isPerfectSolve {
            AnyShapeStyle(
                LinearGradient(
                    colors: [.yellow.opacity(0.72), .white.opacity(0.28), .orange.opacity(0.56)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
        } else {
            AnyShapeStyle(.white.opacity(0.18))
        }
    }
}

private struct FlowProgressView: View {
    let flow: FlowState
    let isHintAssisted: Bool

    var body: some View {
        VStack(spacing: 5) {
            HStack(spacing: 5) {
                Text("Flow \(flow.multiplierLabel)")
                    .font(.system(size: 13, weight: .black, design: .rounded))
                if isHintAssisted {
                    Image(systemName: "sparkles")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(.white.opacity(0.5))
                }
            }
            .foregroundStyle(.white.opacity(0.72))

            HStack(spacing: 4) {
                ForEach(0..<3, id: \.self) { index in
                    Capsule()
                        .fill(index < flow.linksTowardNextTier || flow.isMaxed ? Color.cyan : Color.white.opacity(0.14))
                        .frame(width: 20, height: 5)
                }
            }
        }
        .accessibilityLabel("Flow \(flow.multiplierLabel)")
    }
}

private struct CelebrationRatingButton: View {
    let rating: LevelFeedbackRating
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: rating.systemImage)
                .font(.system(size: 20, weight: .bold))
                .frame(width: 44, height: 40)
                .foregroundStyle(isSelected ? selectedColor : .white.opacity(0.70))
                .background(background, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .stroke(isSelected ? selectedColor.opacity(0.7) : .white.opacity(0.12), lineWidth: 1)
                }
        }
        .buttonStyle(.plain)
        .help(rating.label)
        .accessibilityLabel(rating.label)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    private var selectedColor: Color {
        switch rating {
        case .up: .mint
        case .neutral: .yellow
        case .down: .pink
        }
    }

    private var background: Color {
        isSelected ? selectedColor.opacity(0.18) : .white.opacity(0.08)
    }
}

struct CelebrationActionButton: View {
    let systemName: String
    let label: String
    var isPrimary = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(systemName: systemName)
                    .font(.system(size: 15, weight: .black))
                Text(label)
                    .font(.system(size: 15, weight: .black, design: .rounded))
            }
            .frame(height: 42)
            .frame(minWidth: 86)
            .padding(.horizontal, 4)
            .background(buttonFill, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke(.white.opacity(isPrimary ? 0.26 : 0.12), lineWidth: 1)
            }
        }
        .buttonStyle(.plain)
        .foregroundStyle(.white)
        .help(label)
        .accessibilityLabel(label)
    }

    private var buttonFill: some ShapeStyle {
        isPrimary ? AnyShapeStyle(Color.cyan.opacity(0.28)) : AnyShapeStyle(Color.white.opacity(0.10))
    }
}

struct CelebrationDropletField: View {
    let animate: Bool
    let isPerfect: Bool

    private let colors: [Color] = [
        Color(red: 0.96, green: 0.34, blue: 0.07),
        Color(red: 0.05, green: 0.58, blue: 0.86),
        Color(red: 0.94, green: 0.34, blue: 0.65),
        Color(red: 1.00, green: 0.72, blue: 0.08),
        Color(red: 0.12, green: 0.78, blue: 0.62)
    ]

    var body: some View {
        GeometryReader { proxy in
            ForEach(0..<particleCount, id: \.self) { index in
                Image(systemName: symbol(for: index))
                    .font(.system(size: CGFloat(8 + (index % 5) * 3), weight: .black))
                    .foregroundStyle(color(for: index).opacity(isPerfect ? 0.92 : 0.86))
                    .position(
                        x: proxy.size.width * xPosition(for: index),
                        y: proxy.size.height * (animate ? yEndPosition(for: index) : 0.48)
                    )
                    .rotationEffect(.degrees(animate ? Double(index * 31) : 0))
                    .opacity(animate ? 1 : 0)
                    .animation(.spring(response: 0.62, dampingFraction: 0.74).delay(Double(index % 7) * 0.025), value: animate)
            }
        }
    }

    private var particleCount: Int {
        isPerfect ? 34 : 22
    }

    private func symbol(for index: Int) -> String {
        if isPerfect && index % 3 == 0 {
            return "star.fill"
        }

        return index % 4 == 0 ? "sparkle" : "drop.fill"
    }

    private func color(for index: Int) -> Color {
        if isPerfect && index % 3 == 0 {
            return index.isMultiple(of: 2) ? .yellow : .orange
        }

        return colors[index % colors.count]
    }

    private func xPosition(for index: Int) -> CGFloat {
        CGFloat(12 + ((index * 37) % 76)) / 100
    }

    private func yEndPosition(for index: Int) -> CGFloat {
        CGFloat(16 + ((index * 29) % 58)) / 100
    }
}

private struct PerfectBurstView: View {
    let animate: Bool

    var body: some View {
        ZStack {
            ForEach(0..<14, id: \.self) { index in
                Capsule()
                    .fill(index.isMultiple(of: 2) ? Color.yellow.opacity(0.82) : Color.white.opacity(0.50))
                    .frame(width: 3, height: 18)
                    .offset(y: animate ? -52 : -20)
                    .rotationEffect(.degrees(Double(index) / 14 * 360))
                    .opacity(animate ? 1 : 0)
                    .scaleEffect(animate ? 1 : 0.4)
                    .animation(.spring(response: 0.60, dampingFraction: 0.70).delay(Double(index % 5) * 0.018), value: animate)
            }
        }
        .rotationEffect(.degrees(animate ? 22 : 0))
    }
}
