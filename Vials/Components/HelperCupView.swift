import SwiftUI

struct HelperCupView: View {
    let cup: HelperCup
    let unitHeight: CGFloat
    var visualPour: VisualPourAdjustment?
    var showsAddState = false

    var body: some View {
        ZStack {
            VialView(
                vial: Vial(fluids: showsAddState ? [] : cup.fluids, capacity: cup.capacity),
                unitHeight: unitHeight,
                visualPour: showsAddState ? nil : visualPour
            )

            if showsAddState {
                VialShape(capacity: cup.capacity, unitHeight: unitHeight)
                    .stroke(.white.opacity(0.12), style: StrokeStyle(lineWidth: 1.5 * scale, dash: [3 * scale, 4 * scale]))
                    .padding(5 * scale)
            }
        }
    }

    private var scale: CGFloat {
        unitHeight / 30
    }
}
