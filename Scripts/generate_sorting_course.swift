import Foundation
import Darwin

/// Offline authoring helper for the frozen Sorting Course. This executable is
/// not part of the app; paste its accepted output into LabSortingCourse.swift.
/// Optional numeric arguments limit output to particular course levels.
@main struct GenerateSortingCourse {
    static let profiles:[(LevelMode,Int)] =
        (1...8).map {(.easy,$0)} +
        (1...9).map {(.medium,$0)} +
        // Cap this batch at the ten-vial Hard 29 profile. Four distinct
        // alternate boards finish the batch without the 11–12-vial jump.
        (1...29).map {(.hard,$0)} +
        (22...25).map {(.hard,$0)}

    static func main() {
        let requested=Set(CommandLine.arguments.dropFirst().compactMap(Int.init))
        for (offset,profile) in profiles.enumerated() {
            let courseNumber=offset+1
            guard requested.isEmpty || requested.contains(courseNumber) else {continue}
            let source=acceptedSource(mode:profile.0,number:profile.1,discovery:courseNumber.isMultiple(of:5),
                                      minimumVariant:courseNumber>=47 ? 1:0)
            let layers=source.vials.map { vial in vial.fluids.map(pigment) }
            let capacities=source.vials.map(\.capacity)
            print("case \(courseNumber):return LabBoardState(layers:\(layers),capacities:\(capacities),behavior:\(courseNumber.isMultiple(of:5) ? ".discovery": ".sorting"),obscured:\(courseNumber.isMultiple(of:5))) // \(profile.0.rawValue) \(profile.1), variant \(source.generationVariant)")
        }
    }

    /// Original's tuning pass supplies the first candidate. The frozen Lab
    /// course additionally requires a route under the shipping Lab solver;
    /// if the engines' pruning differs, search another profile-compatible variant.
    static func acceptedSource(mode:LevelMode,number:Int,discovery:Bool,minimumVariant:Int)->VialLevel {
        let tuned=VialLevelGenerator.generateTuned(mode:mode,number:number)
        if tuned.generationVariant>=minimumVariant,
           labState(tuned,discovery:discovery).solution(limit:1_500_000) != nil {return tuned}
        for variant in minimumVariant..<80 where variant != tuned.generationVariant {
            print("Trying \(mode.rawValue) \(number), variant \(variant)…")
            fflush(stdout)
            let candidate=VialLevelGenerator.generate(mode:mode,number:number,generationVariant:variant)
            guard labState(candidate,discovery:discovery).solution(limit:600_000) != nil else {continue}
            return candidate
        }
        preconditionFailure("No Lab-accepted candidate for \(mode.rawValue) \(number)")
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
