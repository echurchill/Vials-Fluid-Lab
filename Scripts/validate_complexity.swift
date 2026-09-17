import Foundation

@main
struct ComplexityValidation {
    static func main() throws {
        var failures:[String]=[]
        let legacyPuzzles=Array(LabBoardPuzzle.allCases.prefix(12))
        for puzzle in legacyPuzzles {
            let state=puzzle.initial
            if state.capacities != Array(repeating:4,count:state.stacks.count) {failures.append("\(puzzle.rawValue): legacy capacities changed")}
            if state.rules.contains(where:{$0 != .normal}) {failures.append("\(puzzle.rawValue): legacy rules changed")}
        }

        let expected:[LabBoardPuzzle:(vials:Int,colors:Int,maximum:Int,valves:Int)]=[
            .fiveStreams:(8,5,5,0),.tallOrder:(8,5,6,0),.sixfold:(10,6,6,0),.valveCircuit:(8,5,6,2)]
        for (puzzle,metadata) in expected {
            let state=puzzle.initial
            if state.stacks.count != metadata.vials || Set(state.colors).count != metadata.colors ||
                state.maximumCapacity != metadata.maximum || state.rules.filter({$0 == .receiveOnly}).count != metadata.valves {
                failures.append("\(puzzle.rawValue): incorrect complexity metadata")
            }
        }

        for puzzle in LabBoardPuzzle.allCases {
            let initial=puzzle.initial,start=ProcessInfo.processInfo.systemUptime
            guard let route=initial.solution() else {failures.append("\(puzzle.rawValue): no solution");continue}
            var state=initial
            for move in route {
                if state.rules[move.source] == .receiveOnly {failures.append("\(puzzle.rawValue): route pours from a fill-only vial");break}
                guard let next=state.applying(move) else {failures.append("\(puzzle.rawValue): invalid route move");break}
                state=next
            }
            if !state.solved {failures.append("\(puzzle.rawValue): route did not solve")}
            print("PASS \(puzzle.rawValue): \(route.count) moves · \(String(format:"%.3f",ProcessInfo.processInfo.systemUptime-start)) s")
        }

        let legacy=Data(#"{"colors":[0,1],"stacks":[[0],[1],[]],"capacity":4}"#.utf8)
        let migrated=try JSONDecoder().decode(LabBoardState.self,from:legacy)
        if migrated.capacities != [4,4,4] || migrated.rules != [.normal,.normal,.normal] {failures.append("legacy save migration")}
        let valve=LabBoardPuzzle.valveCircuit.initial
        let roundTrip=try JSONDecoder().decode(LabBoardState.self,from:JSONEncoder().encode(valve))
        if roundTrip != valve {failures.append("new save round trip")}

        let ruleFixture=LabBoardState(layers:[[0],[0],[]],capacities:[2,3,3],rules:[.receiveOnly,.normal,.normal])
        if ruleFixture.move(from:0,to:2) != nil {failures.append("fill-only vial poured out")}
        guard let fill=ruleFixture.move(from:1,to:0),ruleFixture.applying(fill)?.isComplete(0)==true else {failures.append("fill-only vial could not receive and complete");printFailures(failures);return}

        let profiles=LabBoardLayout.profiles(capacities:[3,4,5,6,6,4,5,3])
        if abs(profiles[0].height-2.35*0.75)>0.0001 || abs(profiles[4].height-2.35*1.5)>0.0001 {
            failures.append("capacity did not scale vessel height")
        }
        let tubeWidthDifference=abs((profiles[0].radii.max() ?? 0)-(profiles[4].radii.max() ?? 0))
        let unitVolumes=profiles.enumerated().map { $0.element.usableVolume/Float([3,4,5,6,6,4,5,3][$0.offset]) }
        if tubeWidthDifference>0.0001 || unitVolumes.dropFirst().contains(where:{abs($0-unitVolumes[0])>0.0001}) {
            failures.append("capacity scaling changed same-shape width or per-unit volume (width Δ \(tubeWidthDifference), units \(unitVolumes))")
        }

        printFailures(failures)
    }

    private static func printFailures(_ failures:[String]) {
        if failures.isEmpty {print("PASS: complexity model, solvers, valve rules, and save migration")}
        else {for failure in failures {fputs("FAIL: \(failure)\n",stderr)};exit(1)}
    }
}
