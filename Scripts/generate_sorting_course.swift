import Foundation

/// Offline authoring helper for the frozen Sorting Course. This executable is
/// not part of the app; paste its accepted output into LabSortingCourse.swift.
@main struct GenerateSortingCourse {
    static let profiles:[(LevelMode,Int)] =
        (1...8).map {(.easy,$0)} +
        (1...9).map {(.medium,$0)} +
        (1...8).map {(.hard,$0)}

    static func main() {
        for (offset,profile) in profiles.enumerated() {
            let courseNumber=offset+1
            let source=VialLevelGenerator.generateTuned(mode:profile.0,number:profile.1)
            let layers=source.vials.map { vial in vial.fluids.map(pigment) }
            let capacities=source.vials.map(\.capacity)
            print("case \(courseNumber):return LabBoardState(layers:\(layers),capacities:\(capacities),behavior:\(courseNumber.isMultiple(of:5) ? ".discovery": ".sorting"),obscured:\(courseNumber.isMultiple(of:5))) // \(profile.0.rawValue) \(profile.1), variant \(source.generationVariant)")
        }
    }

    static func pigment(_ fluid:Fluid)->Int {
        switch fluid {
        case .tide:0;case .ember:1;case .fern:2;case .petal:3
        case .sun:4;case .cream:5;case .violet:6;case .mint:7
        case .ruby:8;case .cobalt:9;case .lime:10;case .pearl:11
        }
    }
}
