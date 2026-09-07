import Foundation

enum MasteryTier: Int, Codable, Comparable {
    case completion = 1
    case good = 2
    case top = 3

    static func < (lhs: MasteryTier, rhs: MasteryTier) -> Bool {
        lhs.rawValue < rhs.rawValue
    }

    var dropletCount: Int { rawValue }

    var label: String {
        switch self {
        case .completion: "Completed"
        case .good: "Great route"
        case .top: "Mastered"
        }
    }

    static func earned(mode: LevelMode, moves: Int, target: Int?) -> MasteryTier {
        guard let target else { return .completion }

        let goodAllowance = allowances(for: mode).good

        if moves <= target { return .top }
        if moves <= target + goodAllowance { return .good }
        return .completion
    }

    static func isWithinCompletionTarget(mode: LevelMode, moves: Int, target: Int?) -> Bool? {
        guard let target else { return nil }
        return moves <= target + allowances(for: mode).completion
    }

    private static func allowances(for mode: LevelMode) -> (good: Int, completion: Int) {
        switch mode {
        case .easy:
            return (2, 5)
        case .medium:
            return (3, 7)
        case .hard:
            return (4, 9)
        case .experiments:
            return (4, 9)
        case .zen:
            return (4, 9)
        }
    }
}

struct FlowState: Codable, Equatable {
    private(set) var links: Int = 0

    var tier: Int { min(4, links / 3) }
    var multiplier: Double { 1 + Double(tier) * 0.25 }
    var multiplierLabel: String {
        multiplier.formatted(.number.precision(.fractionLength(tier == 0 ? 0 : 2))) + "x"
    }
    var linksTowardNextTier: Int { tier == 4 ? 3 : links % 3 }
    var isMaxed: Bool { tier == 4 }

    mutating func addLinks(_ amount: Int) {
        links = min(12, max(0, links + amount))
    }

    mutating func reduceOneTier() {
        links = max(0, links - 3)
    }
}

struct CompletionSummary: Equatable {
    let earnedTier: MasteryTier
    let bestTier: MasteryTier
    let flow: FlowState
    let wasHintAssisted: Bool
}
