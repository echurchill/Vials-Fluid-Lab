import Foundation
import Darwin

/// Offline authoring helper for the frozen Sorting Course. This executable is
/// not part of the app; paste its accepted output into LabSortingCourse.swift.
/// Optional numeric arguments limit output to particular course levels.
@main struct GenerateSortingCourse {
    struct AuthoringProfile {
        let mode:LevelMode
        let number:Int
        let minimumVariant:Int
        let maximumVariant:Int
    }

    static let firstFifty:[AuthoringProfile] =
        (1...8).map {.init(mode:.easy,number:$0,minimumVariant:0,maximumVariant:80)} +
        (1...9).map {.init(mode:.medium,number:$0,minimumVariant:0,maximumVariant:80)} +
        (1...29).map {.init(mode:.hard,number:$0,minimumVariant:0,maximumVariant:80)} +
        (22...25).map {.init(mode:.hard,number:$0,minimumVariant:1,maximumVariant:80)}

    /// Extend the fixed curriculum without crossing the accepted ten-vial
    /// presentation ceiling. Each pass uses a disjoint generation-variant
    /// range, so repeated Hard profiles still produce distinct frozen boards.
    static let secondFifty:[AuthoringProfile] = (0..<50).map { offset in
        let pass=offset/8
        let minimum=[2,13,24,35,46,57,68][pass]
        let maximum=[13,24,35,46,57,68,80][pass]
        return .init(mode:.hard,number:18+offset%8,minimumVariant:minimum,maximumVariant:maximum)
    }

    static let profiles=firstFifty+secondFifty

    static func main() {
        let requested=Set(CommandLine.arguments.dropFirst().compactMap(Int.init))
        for (offset,profile) in profiles.enumerated() {
            let courseNumber=offset+1
            guard requested.isEmpty || requested.contains(courseNumber) else {continue}
            let source=acceptedSource(mode:profile.mode,number:profile.number,discovery:courseNumber.isMultiple(of:5),
                                      minimumVariant:profile.minimumVariant,maximumVariant:profile.maximumVariant)
            let layers=source.vials.map { vial in vial.fluids.map(pigment) }
            let capacities=source.vials.map(\.capacity)
            print("case \(courseNumber):return LabBoardState(layers:\(layers),capacities:\(capacities),behavior:\(courseNumber.isMultiple(of:5) ? ".discovery": ".sorting"),obscured:\(courseNumber.isMultiple(of:5))) // \(profile.mode.rawValue) \(profile.number), variant \(source.generationVariant)")
        }
    }

    /// Original's tuning pass supplies the first candidate. The frozen Lab
    /// course additionally requires a route under the shipping Lab solver;
    /// if the engines' pruning differs, search another profile-compatible variant.
    static func acceptedSource(mode:LevelMode,number:Int,discovery:Bool,minimumVariant:Int,maximumVariant:Int)->VialLevel {
        let tuned=VialLevelGenerator.generateTuned(mode:mode,number:number)
        if minimumVariant..<maximumVariant ~= tuned.generationVariant,
           labState(tuned,discovery:discovery).solution(limit:1_500_000) != nil {return tuned}
        for variant in minimumVariant..<maximumVariant where variant != tuned.generationVariant {
            print("Trying \(mode.rawValue) \(number), variant \(variant)…")
            fflush(stdout)
            let candidate=VialLevelGenerator.generate(mode:mode,number:number,generationVariant:variant)
            guard labState(candidate,discovery:discovery).solution(limit:600_000) != nil else {continue}
            return candidate
        }
        preconditionFailure("No Lab-accepted candidate for \(mode.rawValue) \(number) in variants \(minimumVariant)..<\(maximumVariant)")
    }

    static func labState(_ source:VialLevel,discovery:Bool)->LabBoardState {
        LabBoardState(layers:source.vials.map {$0.fluids.map(pigment)},
                      capacities:source.vials.map(\.capacity),
                      behavior:discovery ? .discovery:.sorting,obscured:discovery)
    }

    static func pigment(_ fluid:Fluid)->Int {
        switch fluid {
        case .tide:0;case .ember:1;case .fern:2;case .petal:3
        case .sun:4;case .cream:5;case .violet:6;case .mint:7
        case .ruby:8;case .cobalt:9;case .lime:10;case .pearl:11
        }
    }
}
