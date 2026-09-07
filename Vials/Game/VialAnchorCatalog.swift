import SwiftUI

enum VialAnchorCatalog {
    nonisolated static func level(mode: LevelMode, number: Int) -> VialLevel? {
        guard mode == .experiments, let lesson = valveLesson(for: number) else { return nil }

        guard let vials = VialLevelGenerator.integratedValveVials(
            sourceMode: lesson.sourceMode,
            number: lesson.sourceNumber,
            valveCount: lesson.valveCount
        ) else {
            return nil
        }

        return VialLevel(
            number: number,
            mode: mode,
            vials: vials,
            zoom: VialLevelGenerator.zoom(for: vials),
            rampMessage: lesson.title,
            targetMoveBand: LevelCurriculum.beat(for: mode, level: number).targetMoveBand,
            isAnchor: true
        )
    }

    nonisolated private static func valveLesson(for number: Int) -> ValveLesson? {
        switch number {
        case 1...5:
            return ValveLesson(
                sourceMode: .easy,
                sourceNumber: number,
                valveCount: 1,
                title: number == 1 ? "Valve primer" : "Valve practice"
            )
        case 6...10:
            return ValveLesson(
                sourceMode: .medium,
                sourceNumber: number - 5,
                valveCount: number >= 8 ? 2 : 1,
                title: number >= 8 ? "Twin valve circuit" : "Valve routing"
            )
        case 11...15:
            return ValveLesson(
                sourceMode: .hard,
                sourceNumber: number - 10,
                valveCount: 2,
                title: "Variable valve lab"
            )
        default:
            return nil
        }
    }
}

private struct ValveLesson {
    let sourceMode: LevelMode
    let sourceNumber: Int
    let valveCount: Int
    let title: String
}
