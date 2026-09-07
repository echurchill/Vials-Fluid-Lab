import SwiftUI

struct HelperCup: Equatable {
    var fluids: [Fluid] = []
    var capacity: Int = 1

    nonisolated var topFluid: Fluid? {
        fluids.last
    }

    nonisolated var availableSpace: Int {
        capacity - fluids.count
    }

    nonisolated var topRunLength: Int {
        guard let topFluid else { return 0 }
        return fluids.reversed().prefix { $0 == topFluid }.count
    }
}
