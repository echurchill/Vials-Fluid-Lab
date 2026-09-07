import SwiftUI

struct VialView: View {
    let vial: Vial
    let unitHeight: CGFloat
    var visualPour: VisualPourAdjustment?
    var valvePulse = false

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                VialShape(capacity: vial.capacity, unitHeight: unitHeight)
                    .fill(.white.opacity(0.05))

                liquidStack(in: proxy.size)

                destinationFillOverlay(in: proxy.size)

                VialShape(capacity: vial.capacity, unitHeight: unitHeight)
                    .stroke(
                        LinearGradient(
                            colors: [.white.opacity(0.24), .indigo.opacity(0.74), .white.opacity(0.20)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 4 * scale
                    )

                VialShape(capacity: vial.capacity, unitHeight: unitHeight)
                    .stroke(.black.opacity(0.28), lineWidth: 1 * scale)
                    .padding(3 * scale)

                VialTopRimShape(capacity: vial.capacity, unitHeight: unitHeight)
                    .stroke(.white.opacity(0.28), style: StrokeStyle(lineWidth: 4 * scale, lineCap: .round))

                if vial.rule == .receiveOnly {
                    VialTopRimShape(capacity: vial.capacity, unitHeight: unitHeight)
                        .stroke(.cyan.opacity(valvePulse ? 1 : 0.72), style: StrokeStyle(lineWidth: 4 * scale, lineCap: .round))

                    ZStack {
                        Circle()
                            .fill(.indigo.opacity(0.86))
                        Circle()
                            .stroke(.cyan.opacity(valvePulse ? 1 : 0.82), lineWidth: 1.5 * scale)
                        Image(systemName: "arrow.down")
                            .font(.system(size: 14 * scale, weight: .black))
                            .foregroundStyle(.cyan)
                    }
                    .frame(width: 23 * scale, height: 23 * scale)
                    .shadow(color: .cyan.opacity(valvePulse ? 0.82 : 0.36), radius: 6 * scale)
                    .position(x: proxy.size.width / 2, y: 17 * scale)
                    .scaleEffect(valvePulse ? 1.32 : 1)
                        .animation(.spring(response: 0.22, dampingFraction: 0.46), value: valvePulse)
                }
            }
        }
    }

    @ViewBuilder
    private func liquidStack(in size: CGSize) -> some View {
        if let visualPour, visualPour.role == .source {
            sourceDrainingLiquidStack(visualPour, in: size)
        } else {
            LiquidStackView(
                fluids: visualPour?.baseFluids ?? vial.fluids,
                capacity: vial.capacity,
                unitHeight: unitHeight,
                profile: .vial,
                showsTopSurface: !isDestinationReceiving
            )
        }
    }

    private func sourceDrainingLiquidStack(_ visualPour: VisualPourAdjustment, in size: CGSize) -> some View {
        let remainingTransfers = visualPour.transfers.filter { $0.progress < 1 }
        let remainingPourHeight = remainingTransfers.reduce(CGFloat.zero) { partial, transfer in
            partial + CGFloat(transfer.amount) * max(0, 1 - transfer.progress) * unitHeight
        }
        let bottomY = fluidBottomY(filledUnits: visualPour.baseFluids.count, in: size)

        return ZStack {
            LiquidStackView(
                fluids: visualPour.baseFluids,
                capacity: vial.capacity,
                unitHeight: unitHeight,
                profile: .vial,
                showsTopSurface: remainingPourHeight <= 0.5
            )

            if remainingPourHeight > 0.5 {
                VStack(spacing: 0) {
                    ForEach(Array(remainingTransfers.enumerated()), id: \.offset) { offset, transfer in
                        let height = CGFloat(transfer.amount) * max(0, 1 - transfer.progress) * unitHeight
                        FluidSegment(
                            fluid: transfer.fluid,
                            seed: visualPour.baseFluids.count + offset,
                            unitCount: max(1, transfer.amount),
                            showsBottomDepth: visualPour.baseFluids.isEmpty && offset == 0
                        )
                        .frame(width: size.width, height: height)
                    }
                }
                .frame(width: size.width, height: remainingPourHeight, alignment: .bottom)
                .position(x: size.width / 2, y: bottomY - remainingPourHeight / 2)
                .clipShape(VialInteriorShape(capacity: vial.capacity, unitHeight: unitHeight))
            }
        }
    }

    @ViewBuilder
    private func destinationFillOverlay(in size: CGSize) -> some View {
        if let visualPour, visualPour.role == .destination {
            destinationFill(visualPour, in: size)
        }
    }

    private func destinationFill(_ visualPour: VisualPourAdjustment, in size: CGSize) -> some View {
        let fillHeight = visualPour.transfers.reduce(CGFloat.zero) { partial, transfer in
            partial + CGFloat(transfer.amount) * min(1, max(0, transfer.progress)) * unitHeight
        }
        let bottomY = fluidBottomY(filledUnits: visualPour.baseFluids.count, in: size)

        return VStack(spacing: 0) {
            ForEach(Array(visualPour.transfers.enumerated()), id: \.offset) { offset, transfer in
                let height = CGFloat(transfer.amount) * min(1, max(0, transfer.progress)) * unitHeight
                FluidSegment(
                    fluid: transfer.fluid,
                    seed: visualPour.baseFluids.count + offset,
                    unitCount: max(1, transfer.amount),
                    showsBottomDepth: visualPour.baseFluids.isEmpty && offset == 0
                )
                .frame(width: size.width, height: height)
            }
        }
        .frame(width: size.width, height: max(fillHeight, 1), alignment: .bottom)
        .position(x: size.width / 2, y: bottomY - fillHeight / 2)
        .shadow(color: visualPour.transfers.first?.fluid.color.opacity(0.24) ?? .clear, radius: 10 * scale)
        .clipShape(VialInteriorShape(capacity: vial.capacity, unitHeight: unitHeight))
    }

    private var isDestinationReceiving: Bool {
        guard let visualPour, visualPour.role == .destination else { return false }
        return visualPour.transfers.contains { $0.progress > 0 }
    }

    private func fluidBottomY(filledUnits: Int, in size: CGSize) -> CGFloat {
        size.height - 12 * scale - CGFloat(filledUnits) * unitHeight
    }

    private var scale: CGFloat {
        unitHeight / 30
    }
}
