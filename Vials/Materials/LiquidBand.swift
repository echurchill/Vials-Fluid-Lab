import SwiftUI

struct LiquidBand {
    let top: CGFloat
    let bottom: CGFloat

    var height: CGFloat {
        bottom - top
    }

    var midY: CGFloat {
        top + (height / 2)
    }
}
