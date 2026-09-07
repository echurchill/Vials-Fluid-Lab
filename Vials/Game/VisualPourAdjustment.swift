import SwiftUI

struct VisualPourAdjustment: Equatable {
    enum Role: Equatable {
        case source
        case destination
    }

    let role: Role
    let baseFluids: [Fluid]
    let transfers: [Transfer]

    struct Transfer: Equatable {
        let fluid: Fluid
        let amount: Int
        let progress: CGFloat
    }
}
