import SwiftUI

struct LiquidRun: Identifiable {
    let fluid: Fluid
    let startIndex: Int
    let endIndex: Int
    let unitCount: Int
    let showsSurface: Bool
    let showsBottomDepth: Bool
    let band: LiquidBand

    var id: String { "\(fluid.rawValue)-\(startIndex)-\(endIndex)-\(unitCount)" }
}
