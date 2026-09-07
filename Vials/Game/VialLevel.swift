import SwiftUI

struct VialLevel {
    let number: Int
    let mode: LevelMode
    let vials: [Vial]
    let zoom: CGFloat
    let rampMessage: String?
    let targetMoveBand: ClosedRange<Int>
    let isAnchor: Bool
    let exactMinimumMoveCount: Int?
    let generationVariant: Int

    nonisolated init(
        number: Int,
        mode: LevelMode,
        vials: [Vial],
        zoom: CGFloat,
        rampMessage: String? = nil,
        targetMoveBand: ClosedRange<Int> = 0...0,
        isAnchor: Bool = false,
        exactMinimumMoveCount: Int? = nil,
        generationVariant: Int = 0
    ) {
        self.number = number
        self.mode = mode
        self.vials = vials
        self.zoom = zoom
        self.rampMessage = rampMessage
        self.targetMoveBand = targetMoveBand
        self.isAnchor = isAnchor
        self.exactMinimumMoveCount = exactMinimumMoveCount
        self.generationVariant = generationVariant
    }

    nonisolated var maxCapacity: Int {
        vials.map(\.capacity).max() ?? 4
    }
}
