import Foundation

@main struct ValidateKeystoneLabs {
    static func emit(_ value:String) { FileHandle.standardOutput.write(Data((value+"\n").utf8)) }
    static func main() {
        var failures:[String]=[]
        let densityFixture=LabBoardState(
            layers:[[0],[8],[]],capacities:[1,1,2],densityLayers:[[.light],[.heavy],[]],behavior:.density)
        if let light=densityFixture.move(from:0,to:2),let afterLight=densityFixture.applying(light),
           let heavy=afterLight.move(from:1,to:2),let settled=afterLight.applying(heavy) {
            if settled.stacks[2].map(settled.material) != [.init(8,.heavy),.init(0,.light)] {
                failures.append("density settlement did not order heavy below light")
            }
        } else {failures.append("density mode rejected unlike-material destination")}

        let surplusFixture=LabBoardState(
            layers:[[8],[0]],capacities:[1,1],densityLayers:[[.heavy],[.light]],behavior:.density,
            targets:[.init(vial:0,layers:[.init(8,.heavy)])])
        if !surplusFixture.solved {failures.append("harmless surplus invalidated a completed target")}

        let mixedDensityMixer=LabBoardState(
            layers:[[8],[4],[]],capacities:[1,1,2],rules:[.normal,.normal,.sourceOnly],
            densityLayers:[[.light],[.medium],[]],behavior:.mixing,apparatus:[.mixer(inputs:[0,1],output:2)])
        if mixedDensityMixer.canActivate(.init(apparatusID:0)) {failures.append("mixer accepted unequal densities")}
        if mixedDensityMixer.move(from:0,to:2) != nil {failures.append("source-only mixer output accepted a pour")}

        let modifier=LabBoardState(
            layers:[[0,0]],capacities:[2],densityLayers:[[.medium,.medium]],behavior:.crossover,
            apparatus:[.modifier(chamber:0,direction:.heavier)])
        if modifier.applying(.init(apparatusID:0))?.densities != [.heavy,.heavy] {
            failures.append("density modifier did not transform the whole homogeneous batch")
        }

        for discipline in LabDiscipline.allCases {
            for puzzle in discipline.levels {
                emit("checking \(discipline.rawValue) \(puzzle.rawValue)")
                let initial=puzzle.initial
                let encoded=try! JSONEncoder().encode(initial)
                let decoded=try! JSONDecoder().decode(LabBoardState.self,from:encoded)
                if decoded != initial {failures.append("\(puzzle.rawValue): state round trip changed")}
                if initial.colors.count != initial.densities.count {failures.append("\(puzzle.rawValue): material arrays differ")}
                if discipline == .sorting {
                    continue // The established progression suite owns the larger legacy solver matrix.
                } else {
                    guard let route=puzzle.authoredRoute(from:initial) ?? initial.operationSolution() else {failures.append("\(puzzle.rawValue): no operation solution");continue}
                    var state=initial
                    for operation in route {
                        let before=state.stacks.flatMap {$0}.sorted()
                        guard let next=state.applying(operation) else {failures.append("\(puzzle.rawValue): invalid operation route");break}
                        let after=next.stacks.flatMap {$0}.sorted()
                        if before != after {failures.append("\(puzzle.rawValue): inventory changed")}
                        state=next
                    }
                    if !state.solved {failures.append("\(puzzle.rawValue): operation route did not solve")}
                    emit("\(discipline.rawValue) \(puzzle.rawValue): \(route.count) operations")
                }
            }
        }
        precondition(failures.isEmpty,failures.joined(separator:"\n"))
        emit("Keystone model validation passed for \(LabBoardPuzzle.allCases.count) levels.")
    }
}
