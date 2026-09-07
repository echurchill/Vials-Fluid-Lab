import SwiftUI

enum LiquidContainerProfile {
    case vial
    case cup

    func bands(for filledUnits: Int, capacity: Int, unitHeight: CGFloat, in size: CGSize) -> [LiquidBand] {
        guard filledUnits > 0, capacity > 0 else { return [] }
        let scale = unitHeight / 30
        let bottomY = size.height - 12 * scale

        return (0..<filledUnits).map { index in
            let bottom = bottomY - CGFloat(index) * unitHeight
            return LiquidBand(
                top: bottom - unitHeight,
                bottom: bottom
            )
        }
    }
}
