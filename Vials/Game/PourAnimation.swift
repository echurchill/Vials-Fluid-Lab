import SwiftUI

struct PourAnimation: Equatable {
    let id: UUID
    let source: ContainerRef
    let destination: ContainerRef
    let fluid: Fluid
    let amount: Int

    nonisolated init(
        id: UUID = UUID(),
        source: ContainerRef,
        destination: ContainerRef,
        fluid: Fluid,
        amount: Int
    ) {
        self.id = id
        self.source = source
        self.destination = destination
        self.fluid = fluid
        self.amount = amount
    }
}
