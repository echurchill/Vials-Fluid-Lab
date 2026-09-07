import Foundation

enum LevelBeatKind: String {
    case standard
    case breather
    case challenge
    case anchor
}

struct LevelBeat {
    let levels: ClosedRange<Int>
    let colorCounts: ClosedRange<Int>
    let capacities: ClosedRange<Int>
    let emptyVialCount: Int
    let duplicateTargets: ClosedRange<Int>
    let variableHeights: Bool
    let scrambleLayers: ClosedRange<Int>
    let targetMoveBand: ClosedRange<Int>
    let kind: LevelBeatKind
}

enum LevelCurriculum {
    nonisolated static func beat(for mode: LevelMode, level: Int) -> LevelBeat {
        let level = max(1, level)

        switch mode {
        case .easy:
            if level <= 10 {
                return LevelBeat(levels: 1...10, colorCounts: 3...3, capacities: 3...4, emptyVialCount: 1, duplicateTargets: 0...0, variableHeights: false, scrambleLayers: 2...3, targetMoveBand: 5...14, kind: .standard)
            }
            if level <= 25 {
                return LevelBeat(levels: 11...25, colorCounts: 4...5, capacities: 4...4, emptyVialCount: 2, duplicateTargets: 0...0, variableHeights: false, scrambleLayers: 3...4, targetMoveBand: 10...24, kind: .standard)
            }
            return LevelBeat(levels: 26...Int.max, colorCounts: 5...7, capacities: 4...5, emptyVialCount: 2, duplicateTargets: 0...0, variableHeights: false, scrambleLayers: 4...5, targetMoveBand: 18...34, kind: .standard)

        case .medium:
            if level <= 12 {
                return LevelBeat(levels: 1...12, colorCounts: 3...4, capacities: 4...4, emptyVialCount: 1, duplicateTargets: 1...1, variableHeights: false, scrambleLayers: 3...4, targetMoveBand: 10...24, kind: .standard)
            }
            if level <= 30 {
                return LevelBeat(levels: 13...30, colorCounts: 4...6, capacities: 4...5, emptyVialCount: 2, duplicateTargets: 1...2, variableHeights: false, scrambleLayers: 4...5, targetMoveBand: 18...38, kind: .standard)
            }
            return LevelBeat(levels: 31...Int.max, colorCounts: 6...8, capacities: 5...6, emptyVialCount: 2, duplicateTargets: 2...4, variableHeights: false, scrambleLayers: 5...6, targetMoveBand: 28...52, kind: .standard)

        case .hard:
            if level <= 12 {
                return LevelBeat(levels: 1...12, colorCounts: 4...5, capacities: 3...5, emptyVialCount: 2, duplicateTargets: 0...1, variableHeights: true, scrambleLayers: 3...4, targetMoveBand: 14...30, kind: .standard)
            }
            if level <= 25 {
                return LevelBeat(levels: 13...25, colorCounts: 5...6, capacities: 3...6, emptyVialCount: 2, duplicateTargets: 1...2, variableHeights: true, scrambleLayers: 4...5, targetMoveBand: 22...44, kind: .standard)
            }
            return LevelBeat(levels: 26...Int.max, colorCounts: 6...9, capacities: 4...8, emptyVialCount: 2, duplicateTargets: 2...5, variableHeights: true, scrambleLayers: 5...7, targetMoveBand: 32...64, kind: .standard)

        case .experiments:
            if level <= 5 {
                return LevelBeat(levels: 1...5, colorCounts: 3...3, capacities: 2...3, emptyVialCount: 1, duplicateTargets: 0...0, variableHeights: false, scrambleLayers: 2...3, targetMoveBand: 6...16, kind: .anchor)
            }
            if level <= 10 {
                return LevelBeat(levels: 6...10, colorCounts: 3...4, capacities: 3...4, emptyVialCount: 1, duplicateTargets: 1...1, variableHeights: false, scrambleLayers: 3...4, targetMoveBand: 12...28, kind: .anchor)
            }
            return LevelBeat(levels: 11...15, colorCounts: 4...5, capacities: 3...5, emptyVialCount: 2, duplicateTargets: 0...1, variableHeights: true, scrambleLayers: 3...4, targetMoveBand: 18...36, kind: .anchor)

        case .zen:
            return LevelBeat(levels: 1...Int.max, colorCounts: 3...12, capacities: 3...8, emptyVialCount: 2, duplicateTargets: 1...7, variableHeights: true, scrambleLayers: 4...8, targetMoveBand: 18...70, kind: .standard)
        }
    }

    nonisolated static func exceptionKind(for mode: LevelMode, level: Int) -> LevelBeatKind? {
        guard mode != .zen, mode != .experiments else { return nil }
        let adjustment = rampAdjustment(for: mode, level: level)
        guard adjustment != 0 else { return nil }
        return adjustment > 0 ? .challenge : .breather
    }

    nonisolated static func rampAdjustment(for mode: LevelMode, level: Int) -> Int {
        guard mode != .zen, mode != .experiments else { return 0 }

        switch mode {
        case .easy:
            if level >= 10, level.isMultiple(of: 13) { return 3 }
            if level >= 8, level.isMultiple(of: 9) { return -2 }
        case .medium:
            if level >= 12, level.isMultiple(of: 17) { return 4 }
            if level >= 9, level.isMultiple(of: 11) { return -3 }
        case .hard:
            if level >= 10, level.isMultiple(of: 15) { return 4 }
            if level >= 8, level.isMultiple(of: 10) { return -3 }
        case .experiments:
            break
        case .zen:
            break
        }

        return 0
    }
}
