import SwiftUI

struct LiquidStackView: View {
    let fluids: [Fluid]
    let capacity: Int
    let unitHeight: CGFloat
    let profile: LiquidContainerProfile
    var visibleUnitCount: Int? = nil
    var showsTopSurface = true

    var body: some View {
        GeometryReader { proxy in
            let bands = profile.bands(for: fluids.count, capacity: capacity, unitHeight: unitHeight, in: proxy.size)
            let layers = LiquidLayerStack(
                fluids: fluids,
                bands: bands,
                visibleUnitCount: visibleUnitCount ?? fluids.count,
                showsTopSurface: showsTopSurface
            )

            switch profile {
            case .vial:
                layers.clipShape(VialInteriorShape(capacity: capacity, unitHeight: unitHeight))
            case .cup:
                layers.clipShape(RoundedCupInteriorShape(unitHeight: unitHeight))
            }
        }
    }
}
