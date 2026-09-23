import Foundation

extension LabBoardState {
    /// Convert Original curriculum data without carrying any Original gameplay,
    /// animation or asynchronous session behavior into the Lab.
    nonisolated static func adapting(_ source:VialLevel,discovery:Bool=false)->Self {
        let layers=source.vials.map { vial in vial.fluids.map(Self.labPigment) }
        let rules=source.vials.map { $0.rule == .receiveOnly ? LabVialRule.receiveOnly:.normal }
        return Self(layers:layers,capacities:source.vials.map(\.capacity),rules:rules,
                    behavior:discovery ? .discovery:.sorting,obscured:discovery)
    }

    private nonisolated static func labPigment(_ fluid:Fluid)->Int {
        switch fluid {
        case .tide:0
        case .ember:1
        case .fern:2
        case .petal:3
        case .sun:4
        case .cream:5
        case .violet:6
        case .mint:7
        case .ruby:8
        case .cobalt:9
        case .lime:10
        case .pearl:11
        }
    }
}

extension LabEndlessDifficulty {
    nonisolated var originalMode:LevelMode {
        switch self {
        case .easy:.easy
        case .medium:.medium
        case .hard:.hard
        }
    }

    nonisolated init?(_ mode:LevelMode) {
        switch mode {
        case .easy:self = .easy
        case .medium:self = .medium
        case .hard:self = .hard
        case .experiments,.zen:return nil
        }
    }
}

extension LabEndlessBoard {
    /// Preserve Original's deterministic curriculum and color identities while
    /// handing play, animation, saves, Undo and hints to the Lab engine.
    nonisolated static func generated(difficulty:LabEndlessDifficulty,number:Int,generationVariant:Int=0)->Self {
        let number=max(1,number),mode=difficulty.originalMode
        let source=VialLevelGenerator.generate(mode:mode,number:number,generationVariant:generationVariant)
        return Self(difficulty:difficulty,number:number,generationVariant:source.generationVariant,
                    initial:.adapting(source,discovery:number.isMultiple(of:5)))
    }
}
