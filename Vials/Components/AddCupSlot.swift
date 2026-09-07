import SwiftUI

struct AddCupSlot: View {
    let slotHeight: CGFloat
    let vialWidth: CGFloat
    let unitHeight: CGFloat
    let isDisabled: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            ZStack(alignment: .bottom) {
                ZStack {
                    HelperCupView(cup: HelperCup(), unitHeight: unitHeight, showsAddState: true)
                        .frame(width: vialWidth, height: cupHeight)
                        .frame(width: vialWidth, height: slotHeight, alignment: .bottom)

                    Image(systemName: "plus")
                        .font(.system(size: 26 * scale, weight: .black))
                        .foregroundStyle(.white)
                        .offset(y: cupIconOffset)
                }
            }
            .frame(width: vialWidth, height: slotHeight, alignment: .bottom)
            .padding(.vertical, 2 * scale)
            .contentShape(Rectangle())
            .opacity(isDisabled ? 0.46 : 1)
        }
        .buttonStyle(.plain)
        .disabled(isDisabled)
        .help("Add helper cup")
        .accessibilityLabel("Add helper cup")
    }

    private var cupIconOffset: CGFloat {
        let bottomY = cupHeight - 12 * scale
        return bottomY - unitHeight / 2 - cupHeight / 2
    }

    private var scale: CGFloat {
        unitHeight / 30
    }

    private var cupHeight: CGFloat {
        44 * scale + unitHeight
    }
}
