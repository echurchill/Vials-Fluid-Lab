import Foundation
import SwiftUI

@main
struct GeneratedLevelValidation {
    static func main() {
        var failures: [String] = []

        for mode in LevelMode.allCases where mode != .experiments {
            for number in 1...18 {
                let salt: UInt64 = mode == .zen ? 0xC0DE : 0
                let level = VialLevelGenerator.generate(mode: mode, number: number, zenSalt: salt)
                let filled = level.vials.filter { !$0.fluids.isEmpty }
                let empties = level.vials.filter(\.fluids.isEmpty)

                if filled.contains(where: { $0.fluids.count != $0.capacity }) {
                    failures.append("\(mode.displayName) \(number): partial starting vial")
                }

                if empties.isEmpty {
                    failures.append("\(mode.displayName) \(number): no empty vial")
                }

                if filled.allSatisfy(\.isComplete) {
                    failures.append("\(mode.displayName) \(number): generated solved starting state")
                }

                for vial in filled where vial.fluids.count >= 2 && vial.fluids[0] == vial.fluids[1] {
                    failures.append("\(mode.displayName) \(number): matching bottom pair")
                    break
                }

                if mode == .easy {
                    let colorInventory = Dictionary(grouping: filled.flatMap(\.fluids), by: { $0 })
                    let expectedUnits = filled.first?.capacity ?? level.maxCapacity
                    if colorInventory.values.contains(where: { $0.count != expectedUnits }) {
                        failures.append("\(mode.displayName) \(number): repeated color target detected")
                    }
                }

                if mode == .hard || mode == .zen {
                    let capacities = Set(level.vials.map(\.capacity))
                    if capacities.count < 2 {
                        failures.append("\(mode.displayName) \(number): expected variable vial heights")
                    }
                }

                if number <= 4, !VialLevelGenerator.canSolve(level.vials, nodeLimit: 40_000, depthLimit: 50) {
                    failures.append("\(mode.displayName) \(number): solver could not find solution")
                }

                if number <= 3, VialLevelGenerator.minimumMoveCount(level.vials, nodeLimit: 50_000) == nil {
                    failures.append("\(mode.displayName) \(number): minimum move solver could not find optimum")
                }

                if mode != .zen {
                    let hintNodeLimit: Int
                    switch mode {
                    case .easy:
                        hintNodeLimit = 140_000
                    case .medium:
                        hintNodeLimit = 300_000
                    case .hard:
                        hintNodeLimit = 300_000
                    case .experiments:
                        hintNodeLimit = 0
                    case .zen:
                        hintNodeLimit = 0
                    }

                    switch VialLevelGenerator.hint(vials: level.vials, helperBeaker: nil, nodeLimit: hintNodeLimit) {
                    case .move, .solved:
                        break
                    case .deadEnd, .searchLimitReached:
                        failures.append("\(mode.displayName) \(number): initial board has no usable hint")
                    }
                }
            }
        }

        let solvableHintState = [
            Vial(fluids: [.ember, .tide], capacity: 2),
            Vial(fluids: [.tide, .ember], capacity: 2),
            Vial(fluids: [], capacity: 2)
        ]
        switch VialLevelGenerator.hint(vials: solvableHintState, helperBeaker: nil, nodeLimit: 10_000) {
        case .move(let move):
            if move.sourceIndex == move.destinationIndex {
                failures.append("hint solver: returned a self move")
            } else {
                var nextState = solvableHintState
                nextState[move.sourceIndex].fluids.removeLast(move.amount)
                nextState[move.destinationIndex].fluids.append(contentsOf: Array(repeating: move.fluid, count: move.amount))

                if case .deadEnd = VialLevelGenerator.hint(vials: nextState, helperBeaker: nil, nodeLimit: 10_000) {
                    failures.append("hint solver: returned a move into a dead end")
                }
            }
        default:
            failures.append("hint solver: expected a solution-preserving move")
        }

        // A full capacity-two Ember vial must move into the larger empty vial
        // so the remaining Ember can join it and free the small vial for Tide.
        // Pruning every homogeneous-full-to-empty move falsely reports a dead end.
        let unequalCapacityState = [
            Vial(fluids:[.ember,.ember],capacity:2),
            Vial(fluids:[],capacity:3),
            Vial(fluids:[.tide,.ember,.tide],capacity:3)
        ]
        if !VialLevelGenerator.canSolve(unequalCapacityState,nodeLimit:10_000,depthLimit:30) {
            failures.append("solver pruning: unequal-capacity duplicate color reported as a dead end")
        }
        if VialLevelGenerator.minimumMoveCount(unequalCapacityState,nodeLimit:10_000) != 4 {
            failures.append("solver pruning: expected four-move unequal-capacity solution")
        }
        switch VialLevelGenerator.hint(vials:unequalCapacityState,helperBeaker:nil,nodeLimit:10_000) {
        case .move(let move) where move.sourceIndex==0 && move.destinationIndex==1 && move.fluid == .ember && move.amount==2:
            break
        default:
            failures.append("solver pruning: expected the full Ember vial to move into the larger empty vial")
        }

        let deadEndState = [
            Vial(fluids: [.ember, .tide], capacity: 2),
            Vial(fluids: [], capacity: 2)
        ]
        switch VialLevelGenerator.hint(vials: deadEndState, helperBeaker: nil, nodeLimit: 10_000) {
        case .deadEnd:
            break
        default:
            failures.append("hint solver: expected a proven dead end")
        }

        let helperSolvedState = [
            Vial(fluids: [.ember, .ember], capacity: 2),
            Vial(fluids: [.tide, .tide], capacity: 2)
        ]
        let expandedHelper = HelperCup(fluids: [.fern, .fern], capacity: 3)
        if VialLevelGenerator.hint(vials: helperSolvedState, helperBeaker: expandedHelper, nodeLimit: 10_000) != .solved {
            failures.append("hint solver: expected a monochrome expanded helper beaker to settle the level")
        }

        let recoveryHistory = [GameSnapshot(vials: solvableHintState, cup: nil, moveCount: 0)]
        let recovery = VialLevelGenerator.latestSolvableHistory(recoveryHistory, nodeLimit: 10_000)
        if recovery?.historyIndex != 0 || recovery?.actionsToUndo != 1 {
            failures.append("hint solver: expected a solvable recovery snapshot")
        }

        for number in 1...15 {
            let anchor = VialLevelGenerator.generate(mode: .experiments, number: number)
            guard anchor.isAnchor else {
                failures.append("Experiments \(number): expected an authored anchor")
                continue
            }

            let sourceMode: LevelMode = number <= 5 ? .easy : (number <= 10 ? .medium : .hard)
            let sourceNumber = number <= 5 ? number : (number <= 10 ? number - 5 : number - 10)
            let sourceVialCount = VialLevelGenerator.generate(mode: sourceMode, number: sourceNumber).vials.count
            if anchor.vials.count != sourceVialCount {
                failures.append("Experiments \(number): valve board adds vials instead of transforming the source puzzle")
            }

            let valves = anchor.vials.indices.filter { anchor.vials[$0].rule == .receiveOnly }
            if valves.isEmpty {
                failures.append("Experiments \(number): expected a receive-only valve")
            }

            for valve in valves {
                let vial = anchor.vials[valve]
                if vial.fluids.isEmpty || vial.fluids.count >= vial.capacity || Set(vial.fluids).count != 1 {
                    failures.append("Experiments \(number): expected a prefilled single-color valve")
                }

                guard let valveFluid = vial.topFluid else { continue }

                let missingUnits = vial.capacity - vial.fluids.count
                let matchingLooseUnits = anchor.vials
                    .filter { $0.rule == .normal }
                    .flatMap(\.fluids)
                    .filter { $0 == valveFluid }
                    .count
                if matchingLooseUnits < missingUnits {
                    failures.append("Experiments \(number): valve cannot be completed from the board")
                }
                if vial.capacity >= 3 && missingUnits < 2 {
                    failures.append("Experiments \(number): larger valve is missing only one unit")
                }

                let valveFluidIsEmbedded = anchor.vials.contains { candidate in
                    candidate.rule == .normal
                        && candidate.fluids.count > 1
                        && candidate.fluids.contains(valveFluid)
                        && Set(candidate.fluids).count > 1
                }
                if !valveFluidIsEmbedded {
                    failures.append("Experiments \(number): valve color is not embedded in a mixed normal vial")
                }
            }

            if !VialLevelGenerator.canSolve(anchor.vials, nodeLimit: 120_000, depthLimit: 50) {
                failures.append("Experiments \(number): valve anchor has no solution")
            }

            if number <= 10 {
                let minimumMoves = VialLevelGenerator.minimumMoveCount(anchor.vials, nodeLimit: 180_000)
                if let expectedMinimum = anchor.exactMinimumMoveCount, minimumMoves != expectedMinimum {
                    failures.append("Experiments \(number): recorded valve-anchor minimum is incorrect")
                } else if minimumMoves == nil {
                    failures.append("Experiments \(number): solver could not establish a minimum")
                }
            }

            switch VialLevelGenerator.hint(vials: anchor.vials, helperBeaker: nil, nodeLimit: 120_000) {
            case .move(let move):
                if anchor.vials[move.sourceIndex].rule == .receiveOnly {
                    failures.append("Experiments \(number): hint pours from a valve")
                }
            case .solved:
                failures.append("Experiments \(number): valve anchor starts solved")
            case .deadEnd, .searchLimitReached:
                failures.append("Experiments \(number): valve anchor has no usable hint")
            }
        }

        for mode in LevelMode.visibleCases where mode != .experiments {
            for number in 1...40 {
                let level = VialLevelGenerator.generate(mode: mode, number: number)
                if !level.isAnchor, level.vials.contains(where: { $0.rule == .receiveOnly }) {
                    failures.append("\(mode.displayName) \(number): generated catalog unexpectedly contains a valve")
                }
            }
        }

        for mode in [LevelMode.easy, .medium, .hard] {
            for number in 1...3 {
                let tuned = VialLevelGenerator.generateTuned(mode: mode, number: number)
                guard let minimumMoves = tuned.exactMinimumMoveCount else {
                    failures.append("\(mode.displayName) \(number): tuned generation did not verify a minimum")
                    continue
                }

                if !tuned.targetMoveBand.contains(minimumMoves) {
                    failures.append(
                        "\(mode.displayName) \(number): tuned minimum \(minimumMoves) falls outside \(tuned.targetMoveBand)"
                    )
                }
            }
        }

        if MasteryTier.earned(mode: .easy, moves: 10, target: 10) != .top ||
            MasteryTier.earned(mode: .medium, moves: 13, target: 10) != .good ||
            MasteryTier.isWithinCompletionTarget(mode: .hard, moves: 20, target: 10) != false {
            failures.append("mastery thresholds: expected mode allowances")
        }

        var flow = FlowState()
        flow.addLinks(3)
        if flow.multiplierLabel != "1.25x" {
            failures.append("flow: expected 1.25x after three links")
        }
        flow.reduceOneTier()
        if flow.multiplierLabel != "1x" {
            failures.append("flow: expected one-tier reduction")
        }

        if failures.isEmpty {
            print("Generated level validation passed")
        } else {
            failures.forEach { print("FAIL: \($0)") }
            exit(1)
        }
    }
}
