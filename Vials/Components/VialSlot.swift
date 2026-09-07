import SwiftUI

struct VialSlot: View {
    enum PourTilt {
        case left
        case right
    }

    let vial: Vial
    let index: Int
    let slotHeight: CGFloat
    let vialWidth: CGFloat
    let vialHeight: CGFloat
    let unitHeight: CGFloat
    let isSelected: Bool
    let isInvalid: Bool
    let pourTilt: PourTilt?
    let visualPour: VisualPourAdjustment?
    var hintHighlight: HintHighlight?
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            ZStack {
                VialShape(capacity: vial.capacity, unitHeight: unitHeight)
                    .stroke(selectedGlow.opacity(isSelected ? 1 : 0), lineWidth: 5 * scale)
                    .blur(radius: 10 * scale)
                    .frame(width: vialWidth, height: vialHeight)
                    .frame(width: vialWidth, height: slotHeight, alignment: .bottom)

                if let hintColor {
                    VialShape(capacity: vial.capacity, unitHeight: unitHeight)
                        .stroke(hintColor.opacity(0.9), lineWidth: 3 * scale)
                        .blur(radius: 6 * scale)
                        .frame(width: vialWidth, height: vialHeight)
                        .frame(width: vialWidth, height: slotHeight, alignment: .bottom)
                }

                VialView(
                    vial: vial,
                    unitHeight: unitHeight,
                    visualPour: visualPour,
                    valvePulse: vial.rule == .receiveOnly && isInvalid
                )
                    .frame(width: vialWidth, height: vialHeight)
                    .frame(width: vialWidth, height: slotHeight, alignment: .bottom)
                    .transaction { transaction in
                        transaction.animation = nil
                    }
            }
            .padding(.vertical, 2 * scale)
                .offset(y: isSelected ? -18 * scale : 0)
                .offset(x: isInvalid ? -6 * scale : 0)
                .rotationEffect(rotation)
                .scaleEffect(isSelected ? 1.05 : 1)
                .animation(.spring(response: 0.26, dampingFraction: 0.72), value: isSelected)
                .animation(.spring(response: 0.16, dampingFraction: 0.38), value: isInvalid)
                .animation(.easeInOut(duration: 0.22), value: pourTilt)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(accessibilityLabel)
    }

    private var rotation: Angle {
        switch pourTilt {
        case .left: .degrees(-34)
        case .right: .degrees(34)
        case nil: .degrees(0)
        }
    }

    private var selectedGlow: Color {
        vial.topFluid?.color.opacity(0.38) ?? .clear
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
        let ruleDescription = vial.rule == .receiveOnly ? "Receive-only valve. " : ""
        if vial.fluids.isEmpty {
            return "\(ruleDescription)Empty vial \(index + 1)"
        }

        let contents = vial.fluids.reversed().map(\.displayName).joined(separator: ", ")
        return "\(ruleDescription)Vial \(index + 1), top to bottom: \(contents)"
    }
}
