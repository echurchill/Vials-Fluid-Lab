import SwiftUI

enum VialLevelGenerator {
    nonisolated static func generate(
        mode: LevelMode,
        number: Int,
        zenSalt: UInt64 = 0,
        generationVariant: Int = 0
    ) -> VialLevel {
        let levelNumber = max(1, number)
        if let anchor = VialAnchorCatalog.level(mode: mode, number: levelNumber) {
            return anchor
        }
        let profile = LevelProfile(
            mode: mode,
            number: levelNumber,
            zenSalt: zenSalt,
            generationVariant: generationVariant
        )
        var rng = SeededRandomNumberGenerator(seed: profile.seed)
        let targets = makeTargets(for: profile, rng: &rng)
        let emptyCapacities = makeEmptyCapacities(for: profile, targets: targets, rng: &rng)
        let solvedVials = targets.map { target in
            Vial(fluids: Array(repeating: target.fluid, count: target.capacity), capacity: target.capacity)
        } + emptyCapacities.map { Vial(fluids: [], capacity: $0) }
        let scrambledVials = layeredScramble(solvedVials, profile: profile, rng: &rng)

        assert(scrambledVials.allSatisfy { $0.fluids.isEmpty || $0.fluids.count == $0.capacity })

        return VialLevel(
            number: levelNumber,
            mode: mode,
            vials: scrambledVials,
            zoom: zoom(for: scrambledVials),
            rampMessage: profile.rampMessage,
            targetMoveBand: profile.beat.targetMoveBand,
            isAnchor: profile.beat.kind == .anchor,
            generationVariant: generationVariant
        )
    }

    nonisolated static func generateTuned(
        mode: LevelMode,
        number: Int,
        zenSalt: UInt64 = 0,
        candidateLimit: Int = 10
    ) -> VialLevel {
        let initial = generate(mode: mode, number: number, zenSalt: zenSalt)
        guard !initial.isAnchor, mode != .zen else { return initial }

        let nodeLimit = tuningNodeLimit(for: mode)
        var bestCandidate: (level: VialLevel, minimumMoves: Int, distance: Int)?

        for variant in 0..<candidateLimit {
            let candidate = generate(
                mode: mode,
                number: number,
                zenSalt: zenSalt,
                generationVariant: variant
            )
            guard let minimumMoves = minimumMoveCount(candidate.vials, nodeLimit: nodeLimit) else { continue }

            if candidate.targetMoveBand.contains(minimumMoves) {
                return VialLevel(
                    number: candidate.number,
                    mode: candidate.mode,
                    vials: candidate.vials,
                    zoom: candidate.zoom,
                    rampMessage: candidate.rampMessage,
                    targetMoveBand: candidate.targetMoveBand,
                    isAnchor: candidate.isAnchor,
                    exactMinimumMoveCount: minimumMoves,
                    generationVariant: candidate.generationVariant
                )
            }

            let distance = moveBandDistance(minimumMoves, from: candidate.targetMoveBand)
            if bestCandidate == nil || distance < bestCandidate!.distance ||
                (distance == bestCandidate!.distance && minimumMoves > bestCandidate!.minimumMoves) {
                bestCandidate = (candidate, minimumMoves, distance)
            }
        }

        guard let bestCandidate else { return initial }
        return VialLevel(
            number: bestCandidate.level.number,
            mode: bestCandidate.level.mode,
            vials: bestCandidate.level.vials,
            zoom: bestCandidate.level.zoom,
            rampMessage: bestCandidate.level.rampMessage,
            targetMoveBand: bestCandidate.level.targetMoveBand,
            isAnchor: bestCandidate.level.isAnchor,
            exactMinimumMoveCount: bestCandidate.minimumMoves,
            generationVariant: bestCandidate.level.generationVariant
        )
    }

    /// Builds an experimental board by converting normal solved targets into valves
    /// before scrambling the remaining board. This keeps valve constraints inside
    /// the same working space as the rest of the puzzle.
    nonisolated static func integratedValveVials(
        sourceMode: LevelMode,
        number: Int,
        valveCount: Int
    ) -> [Vial]? {
        let levelNumber = max(1, number)

        for variant in 0..<16 {
            let profile = LevelProfile(
                mode: sourceMode,
                number: levelNumber,
                zenSalt: 0,
                generationVariant: 10_000 + variant
            )
            var rng = SeededRandomNumberGenerator(seed: profile.seed)
            let targets = makeTargets(for: profile, rng: &rng)
            let emptyCapacities = makeEmptyCapacities(for: profile, targets: targets, rng: &rng)
            let valveTargetIndices = valveTargetIndices(in: targets, count: valveCount)

            guard valveTargetIndices.count == valveCount, !emptyCapacities.isEmpty else { continue }

            let normalTargets = targets.enumerated().compactMap { index, target -> Vial? in
                guard !valveTargetIndices.contains(index) else { return nil }
                return Vial(
                    fluids: Array(repeating: target.fluid, count: target.capacity),
                    capacity: target.capacity
                )
            }
            var normalVials = layeredScramble(
                normalTargets + emptyCapacities.map { Vial(fluids: [], capacity: $0) },
                profile: profile,
                rng: &rng
            )

            let workspaceIndices = normalVials.indices.filter { normalVials[$0].fluids.isEmpty }
            guard !workspaceIndices.isEmpty else {
                continue
            }

            let valveTargets = valveTargetIndices.map { targets[$0] }
            let valvePlans = valveTargets.map { target in
                ValvePlan(
                    target: target,
                    missingUnits: missingValveUnits(
                        for: target,
                        sourceMode: sourceMode,
                        levelNumber: levelNumber
                    )
                )
            }
            var carrierCells = normalVials.indices.flatMap { vialIndex in
                guard !workspaceIndices.contains(vialIndex), normalVials[vialIndex].fluids.count > 1 else {
                    return [FluidCell]()
                }
                return normalVials[vialIndex].fluids.indices.dropLast().map {
                    FluidCell(vial: vialIndex, position: $0)
                }
            }
            var canEmbedValves = true

            for (valveOffset, plan) in valvePlans.enumerated() {
                for missingOffset in 0..<plan.missingUnits {
                    guard !carrierCells.isEmpty else {
                        canEmbedValves = false
                        break
                    }
                    guard let workspaceIndex = workspaceIndices.first(where: {
                        normalVials[$0].availableSpace > 0
                    }) else {
                        canEmbedValves = false
                        break
                    }

                    let carrierOffset = (valveOffset * 5 + missingOffset * 3 + variant) % carrierCells.count
                    let carrier = carrierCells.remove(at: carrierOffset)
                    let displacedFluid = normalVials[carrier.vial].fluids[carrier.position]
                    normalVials[carrier.vial].fluids[carrier.position] = plan.target.fluid
                    normalVials[workspaceIndex].fluids.append(displacedFluid)
                }

                if !canEmbedValves { break }
            }

            guard canEmbedValves else { continue }

            let valves = valvePlans.map { plan in
                Vial(
                    fluids: Array(repeating: plan.target.fluid, count: plan.target.capacity - plan.missingUnits),
                    capacity: plan.target.capacity,
                    rule: .receiveOnly
                )
            }
            var candidate = normalVials + valves
            candidate.shuffle(using: &rng)

            if canSolve(candidate, nodeLimit: 120_000, depthLimit: 50) {
                return candidate
            }
        }

        return nil
    }

    nonisolated private static func tuningNodeLimit(for mode: LevelMode) -> Int {
        switch mode {
        case .easy: 80_000
        case .medium: 100_000
        case .hard: 120_000
        case .experiments, .zen: 0
        }
    }

    nonisolated private static func valveTargetIndices(in targets: [TargetVial], count: Int) -> [Int] {
        var selected = [Int]()
        var selectedFluids = Set<Fluid>()

        for index in targets.indices {
            let target = targets[index]
            guard target.capacity >= 2, selectedFluids.insert(target.fluid).inserted else { continue }
            selected.append(index)
            if selected.count == count { break }
        }

        return selected
    }

    nonisolated private static func missingValveUnits(
        for target: TargetVial,
        sourceMode: LevelMode,
        levelNumber: Int
    ) -> Int {
        let desiredUnits: Int
        switch sourceMode {
        case .easy:
            desiredUnits = 2
        case .medium:
            desiredUnits = 2
        case .hard:
            desiredUnits = levelNumber <= 2 ? 2 : 3
        case .experiments, .zen:
            desiredUnits = 2
        }

        return min(max(1, desiredUnits), target.capacity - 1)
    }

    nonisolated private static func moveBandDistance(_ moves: Int, from band: ClosedRange<Int>) -> Int {
        if moves < band.lowerBound { return band.lowerBound - moves }
        if moves > band.upperBound { return moves - band.upperBound }
        return 0
    }

    nonisolated private static func makeTargets(for profile: LevelProfile, rng: inout SeededRandomNumberGenerator) -> [TargetVial] {
        let fluids = Array(Fluid.allCases.prefix(profile.colorCount))
        var targets = fluids.map { fluid in
            TargetVial(fluid: fluid, capacity: profile.capacity(rng: &rng))
        }

        for duplicateIndex in 0..<profile.duplicateCount {
            let fluidIndex = (duplicateIndex * 3 + Int.random(in: 0..<fluids.count, using: &rng)) % fluids.count
            targets.append(TargetVial(fluid: fluids[fluidIndex], capacity: profile.capacity(rng: &rng)))
        }

        targets.shuffle(using: &rng)
        return targets
    }

    nonisolated private static func makeEmptyCapacities(
        for profile: LevelProfile,
        targets: [TargetVial],
        rng: inout SeededRandomNumberGenerator
    ) -> [Int] {
        let emptyCount = profile.emptyVialCount

        if !profile.variableHeights {
            let capacity = targets.first?.capacity ?? 4
            return Array(repeating: capacity, count: emptyCount)
        }

        return (0..<emptyCount).map { _ in profile.capacity(rng: &rng) }
    }

    nonisolated private static func layeredScramble(
        _ solvedVials: [Vial],
        profile: LevelProfile,
        rng: inout SeededRandomNumberGenerator
    ) -> [Vial] {
        var best = solvedVials
        var bestScore = Int.min

        for _ in 0..<profile.scrambleAttempts {
            var candidate = solvedVials
            let filledIndices = candidate.indices.filter { !candidate[$0].fluids.isEmpty }
            let maxCapacity = candidate.map(\.capacity).max() ?? 0
            let layerCount = min(maxCapacity, profile.scrambleLayers)

            for layer in 0..<layerCount {
                var activeIndices = filledIndices.filter { candidate[$0].capacity > layer }
                activeIndices.shuffle(using: &rng)
                rotateLayer(layer, in: activeIndices, vials: &candidate, rng: &rng)
            }

            if disorderScore(candidate) == 0 {
                rotateLayer(0, in: filledIndices, vials: &candidate, rng: &rng)
            }

            reduceBottomRepeats(in: &candidate, rng: &rng)

            let score = disorderScore(candidate) * 10
                - bottomRepeatCount(candidate) * 80
                - completeVialCount(candidate) * 30
            if score > bestScore {
                best = candidate
                bestScore = score
            }

            if bottomRepeatCount(candidate) == 0 && completeVialCount(candidate) == 0 {
                return candidate
            }
        }

        return best
    }

    nonisolated private static func rotateLayer(
        _ layer: Int,
        in indices: [Int],
        vials: inout [Vial],
        rng: inout SeededRandomNumberGenerator
    ) {
        let activeIndices = indices.filter { vials[$0].capacity > layer }
        guard activeIndices.count > 1 else { return }

        let values = activeIndices.map { index in
            vials[index].fluids[vials[index].capacity - 1 - layer]
        }
        guard Set(values).count > 1 else { return }

        let shift = Int.random(in: 1..<activeIndices.count, using: &rng)
        for offset in activeIndices.indices {
            let index = activeIndices[offset]
            let value = values[(offset + shift) % values.count]
            vials[index].fluids[vials[index].capacity - 1 - layer] = value
        }
    }

    nonisolated private static func reduceBottomRepeats(
        in vials: inout [Vial],
        rng: inout SeededRandomNumberGenerator
    ) {
        var passCount = 0

        while bottomRepeatCount(vials) > 0 && passCount < 24 {
            passCount += 1
            let currentRepeatCount = bottomRepeatCount(vials)
            var changed = false
            var offenders = vials.indices.filter { index in
                vials[index].fluids.count >= 2 && vials[index].fluids[0] == vials[index].fluids[1]
            }
            offenders.shuffle(using: &rng)

            for sourceVial in offenders {
                let sourcePositions = [0, 1].filter { $0 < vials[sourceVial].fluids.count }
                var swapTargets = fluidCells(in: vials, excluding: sourceVial)
                swapTargets.shuffle(using: &rng)

                for sourcePosition in sourcePositions {
                    for target in swapTargets {
                        guard vials[sourceVial].fluids[sourcePosition] != vials[target.vial].fluids[target.position] else {
                            continue
                        }

                        var candidate = vials
                        candidate[sourceVial].fluids[sourcePosition] = vials[target.vial].fluids[target.position]
                        candidate[target.vial].fluids[target.position] = vials[sourceVial].fluids[sourcePosition]

                        if bottomRepeatCount(candidate) < currentRepeatCount {
                            vials = candidate
                            changed = true
                            break
                        }
                    }

                    if changed { break }
                }

                if changed { break }
            }

            if !changed { break }
        }
    }

    nonisolated private static func fluidCells(in vials: [Vial], excluding excludedVial: Int) -> [FluidCell] {
        vials.indices.flatMap { vialIndex in
            guard vialIndex != excludedVial else { return [FluidCell]() }
            return vials[vialIndex].fluids.indices.map { position in
                FluidCell(vial: vialIndex, position: position)
            }
        }
    }

    nonisolated static func canSolve(_ vials: [Vial], nodeLimit: Int = 80_000, depthLimit: Int? = nil) -> Bool {
        var solver = LevelSolver(vials: vials, nodeLimit: nodeLimit, depthLimit: depthLimit)
        return solver.canSolve()
    }

    nonisolated static func minimumMoveCount(_ vials: [Vial], nodeLimit: Int = 160_000) -> Int? {
        var solver = LevelSolver(vials: vials, nodeLimit: nodeLimit, depthLimit: nil)
        return solver.minimumMoveCount()
    }

    nonisolated static func hint(
        vials: [Vial],
        helperBeaker: HelperCup?,
        nodeLimit: Int = 120_000
    ) -> HintSearchResult {
        var containers = vials
        let helperContainerIndex: Int?
        if let helperBeaker {
            helperContainerIndex = containers.count
            containers.append(Vial(fluids: helperBeaker.fluids, capacity: helperBeaker.capacity, rule: .normal))
        } else {
            helperContainerIndex = nil
        }

        var solver = LevelSolver(
            vials: containers,
            helperContainerIndex: helperContainerIndex,
            nodeLimit: nodeLimit,
            depthLimit: nil
        )

        switch solver.routeHint() {
        case .move(let move, let movesToFinish):
            guard let fluid = containers[move.source].topFluid else { return .searchLimitReached }
            return .move(
                HintMove(
                    sourceIndex: move.source,
                    destinationIndex: move.destination,
                    fluid: fluid,
                    amount: move.amount,
                    movesToFinish: movesToFinish
                )
            )
        case .solved:
            return .solved
        case .deadEnd:
            return .deadEnd
        case .searchLimitReached:
            return .searchLimitReached
        }
    }

    nonisolated static func latestSolvableHistory(
        _ snapshots: [GameSnapshot],
        nodeLimit: Int = 60_000
    ) -> HintRecoveryCandidate? {
        for index in snapshots.indices.reversed() {
            let snapshot = snapshots[index]
            switch hint(vials: snapshot.vials, helperBeaker: snapshot.cup, nodeLimit: nodeLimit) {
            case .move, .solved:
                return HintRecoveryCandidate(
                    historyIndex: index,
                    actionsToUndo: snapshots.count - index
                )
            case .deadEnd, .searchLimitReached:
                continue
            }
        }

        return nil
    }

    nonisolated private static func disorderScore(_ vials: [Vial]) -> Int {
        vials.reduce(0) { score, vial in
            guard vial.fluids.count > 1 else { return score }

            let colorChanges = zip(vial.fluids, vial.fluids.dropFirst()).filter { $0 != $1 }.count
            let mixedBonus = Set(vial.fluids).count > 1 ? 3 : 0
            return score + colorChanges + mixedBonus
        }
    }

    nonisolated private static func bottomRepeatCount(_ vials: [Vial]) -> Int {
        vials.filter { vial in
            vial.fluids.count >= 2 && vial.fluids[0] == vial.fluids[1]
        }.count
    }

    nonisolated private static func completeVialCount(_ vials: [Vial]) -> Int {
        vials.filter { !$0.fluids.isEmpty && $0.isComplete }.count
    }

    nonisolated static func zoom(for vials: [Vial]) -> CGFloat {
        let maxCapacity = vials.map(\.capacity).max() ?? 4
        let totalVials = vials.count
        let capacityZoom = max(0, CGFloat(maxCapacity - 4)) * 0.045
        let crowdZoom = max(0, CGFloat(totalVials - 7)) * 0.026
        return max(0.62, min(1.0, 1.0 - capacityZoom - crowdZoom))
    }
}

private struct LevelProfile {
    let mode: LevelMode
    let number: Int
    let seed: UInt64

    nonisolated init(mode: LevelMode, number: Int, zenSalt: UInt64, generationVariant: Int) {
        self.mode = mode
        self.number = number
        self.seed = mode.seedNamespace
            ^ UInt64(number &* 1_048_583)
            ^ zenSalt
            ^ UInt64(generationVariant &* 4_294_967)
    }

    nonisolated var beat: LevelBeat {
        LevelCurriculum.beat(for: mode, level: rampLevel)
    }

    nonisolated var colorCount: Int {
        steppedValue(in: beat.colorCounts)
    }

    nonisolated var duplicateCount: Int {
        steppedValue(in: beat.duplicateTargets)
    }

    nonisolated var scrambleLayers: Int {
        steppedValue(in: beat.scrambleLayers)
    }

    nonisolated var scrambleAttempts: Int {
        switch mode {
        case .easy: 40
        case .medium: 70
        case .hard: 90
        case .experiments: 0
        case .zen: 90
        }
    }

    nonisolated var variableHeights: Bool {
        beat.variableHeights
    }

    nonisolated var emptyVialCount: Int {
        beat.emptyVialCount
    }

    nonisolated func capacity(rng: inout SeededRandomNumberGenerator) -> Int {
        guard variableHeights else { return steppedValue(in: beat.capacities) }
        return Int.random(in: beat.capacities, using: &rng)
    }

    nonisolated private var rampLevel: Int {
        max(1, number + rampAdjustment)
    }

    nonisolated private var rampAdjustment: Int {
        LevelCurriculum.rampAdjustment(for: mode, level: number)
    }

    nonisolated var rampMessage: String? {
        guard rampAdjustment != 0 else { return nil }
        let kind = rampAdjustment > 0 ? "Challenge" : "Breather"
        return "\(kind): tuned like \(mode.displayName) Level \(rampLevel)"
    }

    nonisolated private func steppedValue(in range: ClosedRange<Int>) -> Int {
        guard range.lowerBound < range.upperBound else { return range.lowerBound }
        let span = range.upperBound - range.lowerBound
        let beatOffset = max(0, rampLevel - beat.levels.lowerBound)
        let beatLength = max(1, beat.levels.upperBound == Int.max ? 24 : beat.levels.count - 1)
        let step = min(span, beatOffset * (span + 1) / beatLength)
        return range.lowerBound + step
    }
}

private struct TargetVial {
    let fluid: Fluid
    let capacity: Int
}

private struct ValvePlan {
    let target: TargetVial
    let missingUnits: Int
}

private struct FluidCell {
    let vial: Int
    let position: Int
}

private struct LevelSolver {
    private let capacities: [Int]
    private let rules: [ContainerRule]
    private let helperContainerIndex: Int?
    private let initialState: [[Int]]
    private let nodeLimit: Int
    private let depthLimit: Int
    private var visited: Set<String> = []
    private var nodesVisited = 0

    nonisolated init(
        vials: [Vial],
        helperContainerIndex: Int? = nil,
        nodeLimit: Int,
        depthLimit: Int?
    ) {
        capacities = vials.map(\.capacity)
        rules = vials.map(\.rule)
        self.helperContainerIndex = helperContainerIndex
        initialState = vials.map { vial in
            vial.fluids.map { fluid in
                Fluid.allCases.firstIndex(of: fluid) ?? 0
            }
        }
        self.nodeLimit = nodeLimit
        self.depthLimit = depthLimit ?? min(60, 16 + initialState.reduce(0) { $0 + $1.count })
    }

    nonisolated mutating func canSolve() -> Bool {
        search(initialState, depthRemaining: depthLimit)
    }

    nonisolated mutating func minimumMoveCount() -> Int? {
        if isSolved(initialState) { return 0 }

        var frontier = [initialState]
        var depth = 0
        visited.insert(canonicalKey(for: initialState))

        while !frontier.isEmpty && nodesVisited < nodeLimit {
            depth += 1
            var nextFrontier: [[[Int]]] = []

            for state in frontier {
                guard nodesVisited < nodeLimit else { return nil }
                nodesVisited += 1

                for move in moves(for: state) {
                    var next = state
                    let fluid = next[move.source].last ?? 0
                    next[move.source].removeLast(move.amount)
                    next[move.destination].append(contentsOf: Array(repeating: fluid, count: move.amount))

                    let key = canonicalKey(for: next)
                    guard visited.insert(key).inserted else { continue }

                    if isSolved(next) {
                        return depth
                    }

                    nextFrontier.append(next)
                }
            }

            frontier = nextFrontier
        }

        return nil
    }

    nonisolated mutating func routeHint() -> SolverHintSearchResult {
        if isSolved(initialState) { return .solved }

        visited.removeAll(keepingCapacity: true)
        nodesVisited = 0

        guard let solution = findSolution(
            from: initialState,
            depthRemaining: depthLimit,
            firstMove: nil,
            movesTaken: 0
        ) else {
            return nodesVisited >= nodeLimit ? .searchLimitReached : .deadEnd
        }

        return .move(solution.firstMove, movesToFinish: solution.movesToFinish)
    }

    nonisolated private mutating func findSolution(
        from state: [[Int]],
        depthRemaining: Int,
        firstMove: SolverMove?,
        movesTaken: Int
    ) -> SolverSolution? {
        if isSolved(state), let firstMove {
            return SolverSolution(firstMove: firstMove, movesToFinish: movesTaken)
        }
        guard depthRemaining > 0, nodesVisited < nodeLimit else { return nil }
        nodesVisited += 1

        let key = canonicalKey(for: state)
        guard visited.insert(key).inserted else { return nil }

        for move in moves(for: state) {
            var next = state
            let fluid = next[move.source].last ?? 0
            next[move.source].removeLast(move.amount)
            next[move.destination].append(contentsOf: Array(repeating: fluid, count: move.amount))

            if let solution = findSolution(
                from: next,
                depthRemaining: depthRemaining - 1,
                firstMove: firstMove ?? move,
                movesTaken: movesTaken + 1
            ) {
                return solution
            }
        }

        return nil
    }

    nonisolated private mutating func search(_ state: [[Int]], depthRemaining: Int) -> Bool {
        if isSolved(state) { return true }
        guard depthRemaining > 0 else { return false }
        guard nodesVisited < nodeLimit else { return false }
        nodesVisited += 1

        let key = canonicalKey(for: state)
        guard visited.insert(key).inserted else { return false }

        for move in moves(for: state) {
            var next = state
            let fluid = next[move.source].last ?? 0
            next[move.source].removeLast(move.amount)
            next[move.destination].append(contentsOf: Array(repeating: fluid, count: move.amount))

            if search(next, depthRemaining: depthRemaining - 1) {
                return true
            }
        }

        return false
    }

    nonisolated private func moves(for state: [[Int]]) -> [SolverMove] {
        var moves: [SolverMove] = []

        // A full homogeneous vial is only a finished color when no more units
        // of that color remain elsewhere on the board. With unequal capacities,
        // relocating it can be necessary to consolidate the color in a larger
        // vial and reuse the smaller container.
        var fluidTotals:[Int:Int]=[:]
        for vial in state { for unit in vial { fluidTotals[unit,default:0] += 1 } }

        for source in state.indices {
            guard rules[source] == .normal else { continue }
            guard let fluid = state[source].last else { continue }
            let runLength = topRunLength(in: state[source])
            let sourceIsComplete = isComplete(state[source], capacity: capacities[source])
            let sourceHoldsAllOfFluid = fluidTotals[fluid,default:0] == state[source].count

            for destination in state.indices where source != destination {
                guard state[destination].count < capacities[destination] else { continue }

                if let destinationFluid = state[destination].last {
                    guard destinationFluid == fluid else { continue }
                } else if sourceIsComplete && sourceHoldsAllOfFluid {
                    continue
                }

                let amount = min(runLength, capacities[destination] - state[destination].count)
                guard amount > 0 else { continue }
                moves.append(SolverMove(source: source, destination: destination, amount: amount))
            }
        }

        return moves.sorted { first, second in
            let firstDestinationFill = state[first.destination].count
            let secondDestinationFill = state[second.destination].count
            if firstDestinationFill != secondDestinationFill {
                return firstDestinationFill > secondDestinationFill
            }
            return first.amount > second.amount
        }
    }

    nonisolated private func isSolved(_ state: [[Int]]) -> Bool {
        state.indices.allSatisfy { index in
            if index == helperContainerIndex {
                return state[index].isEmpty || Set(state[index]).count == 1
            }
            return state[index].isEmpty || isComplete(state[index], capacity: capacities[index])
        }
    }

    nonisolated private func isComplete(_ vial: [Int], capacity: Int) -> Bool {
        vial.count == capacity && Set(vial).count == 1
    }

    nonisolated private func topRunLength(in vial: [Int]) -> Int {
        guard let fluid = vial.last else { return 0 }
        return vial.reversed().prefix { $0 == fluid }.count
    }

    nonisolated private func canonicalKey(for state: [[Int]]) -> String {
        state.indices
            .map { index in
                let kind = index == helperContainerIndex ? "helper" : "vial"
                return "\(kind):\(capacities[index]):\(rules[index].rawValue):" + state[index].map(String.init).joined(separator: ",")
            }
            .sorted()
            .joined(separator: "|")
    }

}

enum HintSearchResult: Equatable {
    case move(HintMove)
    case solved
    case deadEnd
    case searchLimitReached
}

struct HintMove: Equatable {
    let sourceIndex: Int
    let destinationIndex: Int
    let fluid: Fluid
    let amount: Int
    let movesToFinish: Int
}

struct HintRecoveryCandidate: Equatable {
    let historyIndex: Int
    let actionsToUndo: Int
}

private enum SolverHintSearchResult {
    case move(SolverMove, movesToFinish: Int)
    case solved
    case deadEnd
    case searchLimitReached
}

private struct SolverSolution {
    let firstMove: SolverMove
    let movesToFinish: Int
}

private struct SolverMove {
    let source: Int
    let destination: Int
    let amount: Int
}
