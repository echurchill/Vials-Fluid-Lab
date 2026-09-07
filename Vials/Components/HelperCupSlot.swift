import SwiftUI

struct HelperCupSlot: View {
    let cup: HelperCup
    let slotHeight: CGFloat
    let vialWidth: CGFloat
    let unitHeight: CGFloat
    let isSelected: Bool
    let isInvalid: Bool
    let isPouring: Bool
    let visualPour: VisualPourAdjustment?
    let canIncreaseHeight: Bool
    var hintHighlight: HintHighlight?
    let action: () -> Void
    let increaseHeightAction: () -> Void

    var body: some View {
        VStack(spacing: 5 * scale) {
            Button(action: increaseHeightAction) {
                Image(systemName: "plus.circle.fill")
                    .font(.system(size: 18 * scale, weight: .black))
                    .foregroundStyle(canIncreaseHeight ? .cyan : .white.opacity(0.18))
                    .frame(width: 26 * scale, height: 22 * scale)
            }
            .buttonStyle(.plain)
            .disabled(!canIncreaseHeight)
            .help("Add height to helper beaker")
            .accessibilityLabel("Add height to helper beaker")

            Button(action: action) {
                ZStack {
                    VialShape(capacity: cup.capacity, unitHeight: unitHeight)
                        .stroke(selectedGlow.opacity(isSelected ? 1 : 0), lineWidth: 5 * scale)
                        .blur(radius: 10 * scale)

                    if let hintColor {
                        VialShape(capacity: cup.capacity, unitHeight: unitHeight)
                            .stroke(hintColor.opacity(0.9), lineWidth: 3 * scale)
                            .blur(radius: 6 * scale)
                    }

                    HelperCupView(cup: cup, unitHeight: unitHeight, visualPour: visualPour)
                        .transaction { transaction in
                            transaction.animation = nil
                        }
                }
                .frame(width: vialWidth, height: cupHeight)
                .padding(.vertical, 2 * scale)
                .offset(y: isSelected ? -14 * scale : 0)
                .offset(x: isInvalid ? -6 * scale : 0)
                .rotationEffect(isPouring ? .degrees(-20) : .degrees(0))
                .scaleEffect(isSelected ? 1.06 : 1)
                .animation(.spring(response: 0.26, dampingFraction: 0.72), value: isSelected)
                .animation(.spring(response: 0.16, dampingFraction: 0.38), value: isInvalid)
                .animation(.easeInOut(duration: 0.22), value: isPouring)
            }
            .buttonStyle(.plain)
        }
        .frame(width: vialWidth, height: slotHeight, alignment: .bottom)
        .accessibilityLabel(accessibilityLabel)
    }

    private var selectedGlow: Color {
        cup.topFluid?.color.opacity(0.38) ?? .white.opacity(0.1)
    }

    private var hintColor: Color? {
        switch hintHighlight {
        case .source: .cyan
        case .destination: .yellow
        case nil: nil
        }
    }

    private var scale: CGFloat {
        unitHeight / 30
    }

    private var accessibilityLabel: String {
        if !cup.fluids.isEmpty {
            let contents = cup.fluids.reversed().map(\.displayName).joined(separator: ", ")
            return "Helper beaker, top to bottom: \(contents)"
        }

        return "Empty helper beaker"
    }

    private var cupHeight: CGFloat {
        (44 + CGFloat(cup.capacity) * unitHeight / scale) * scale
    }
}
