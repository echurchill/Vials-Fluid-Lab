import SwiftUI

struct Vial: Identifiable, Equatable {
    let id = UUID()
    var fluids: [Fluid]
    let capacity: Int
    let rule: ContainerRule

    nonisolated init(fluids: [Fluid], capacity: Int = 4, rule: ContainerRule = .normal) {
        self.fluids = fluids
        self.capacity = capacity
        self.rule = rule
    }

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

    nonisolated var isComplete: Bool {
        fluids.count == capacity && Set(fluids).count == 1
    }

    nonisolated var canPourOut: Bool {
        rule == .normal
    }
}
