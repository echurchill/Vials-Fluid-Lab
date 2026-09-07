import Foundation

struct LevelResult: Codable, Identifiable, Equatable {
    let id: String
    let mode: String
    let levelNumber: Int
    let zenSalt: String
    var isCompleted: Bool
    var bestMoveCount: Int
    var bestKnownMinimumMoveCount: Int?
    var bestMasteryTier: MasteryTier
    var completionCount: Int
    var wasHintAssisted: Bool
}

enum PlayerResultStore {
    private static let resultsKey = "player.levelResults"
    private static let flowKey = "player.flowState"

    static func result(mode: LevelMode, levelNumber: Int, zenSalt: UInt64) -> LevelResult? {
        loadResults().first { $0.id == resultID(mode: mode, levelNumber: levelNumber, zenSalt: zenSalt) }
    }

    static func recordCompletion(
        mode: LevelMode,
        levelNumber: Int,
        zenSalt: UInt64,
        moveCount: Int,
        minimumMoveCount: Int?,
        hintAssisted: Bool
    ) -> CompletionSummary {
        let id = resultID(mode: mode, levelNumber: levelNumber, zenSalt: zenSalt)
        var results = loadResults()
        let existing = results.first { $0.id == id }
        let knownTarget = minimumMoveCount ?? existing?.bestKnownMinimumMoveCount
        let earnedTier = MasteryTier.earned(mode: mode, moves: moveCount, target: knownTarget)
        let isWithinCompletionTarget = MasteryTier.isWithinCompletionTarget(
            mode: mode,
            moves: moveCount,
            target: knownTarget
        )
        let bestTier = max(existing?.bestMasteryTier ?? .completion, earnedTier)
        let updated = LevelResult(
            id: id,
            mode: mode.rawValue,
            levelNumber: levelNumber,
            zenSalt: String(zenSalt),
            isCompleted: true,
            bestMoveCount: min(existing?.bestMoveCount ?? moveCount, moveCount),
            bestKnownMinimumMoveCount: [existing?.bestKnownMinimumMoveCount, minimumMoveCount].compactMap { $0 }.min(),
            bestMasteryTier: bestTier,
            completionCount: (existing?.completionCount ?? 0) + 1,
            wasHintAssisted: (existing?.wasHintAssisted ?? false) || hintAssisted
        )

        results.removeAll { $0.id == id }
        results.append(updated)
        saveResults(results)

        var flow = loadFlow()
        if mode != .experiments, !hintAssisted, let isWithinCompletionTarget {
            if isWithinCompletionTarget {
                flow.addLinks(flowLinkChange(for: earnedTier, mode: mode))
            } else {
                flow.reduceOneTier()
            }
        }
        saveFlow(flow)

        return CompletionSummary(
            earnedTier: earnedTier,
            bestTier: bestTier,
            flow: flow,
            wasHintAssisted: hintAssisted
        )
    }

    static func applyRestartFlowPenalty() {
        var flow = loadFlow()
        flow.reduceOneTier()
        saveFlow(flow)
    }

    static func recordKnownMinimum(
        mode: LevelMode,
        levelNumber: Int,
        zenSalt: UInt64,
        minimumMoveCount: Int
    ) {
        let id = resultID(mode: mode, levelNumber: levelNumber, zenSalt: zenSalt)
        var results = loadResults()
        guard let index = results.firstIndex(where: { $0.id == id }) else { return }
        results[index].bestKnownMinimumMoveCount = min(
            results[index].bestKnownMinimumMoveCount ?? minimumMoveCount,
            minimumMoveCount
        )
        saveResults(results)
    }

    static func flow() -> FlowState {
        loadFlow()
    }

    private static func flowLinkChange(for tier: MasteryTier, mode: LevelMode) -> Int {
        switch (tier, mode) {
        case (.top, .easy): 2
        case (.top, .medium): 3
        case (.top, .hard), (.top, .zen): 4
        case (.top, .experiments): 0
        case (.good, .easy): 1
        case (.good, .medium): 2
        case (.good, .hard), (.good, .zen): 3
        case (.good, .experiments): 0
        case (.completion, .hard), (.completion, .zen): 1
        case (.completion, .easy), (.completion, .medium), (.completion, .experiments): 0
        }
    }

    private static func resultID(mode: LevelMode, levelNumber: Int, zenSalt: UInt64) -> String {
        "\(mode.rawValue)-\(levelNumber)-\(zenSalt)"
    }

    private static func loadResults() -> [LevelResult] {
        guard let data = UserDefaults.standard.data(forKey: resultsKey) else { return [] }
        return (try? JSONDecoder().decode([LevelResult].self, from: data)) ?? []
    }

    private static func saveResults(_ results: [LevelResult]) {
        UserDefaults.standard.set(try? JSONEncoder().encode(results), forKey: resultsKey)
    }

    private static func loadFlow() -> FlowState {
        guard let data = UserDefaults.standard.data(forKey: flowKey),
              let flow = try? JSONDecoder().decode(FlowState.self, from: data) else {
            return FlowState()
        }
        return flow
    }

    private static func saveFlow(_ flow: FlowState) {
        UserDefaults.standard.set(try? JSONEncoder().encode(flow), forKey: flowKey)
    }
}
