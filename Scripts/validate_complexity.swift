import Foundation

@main
struct ComplexityValidation {
    static func main() throws {
        var failures:[String]=[]
        let legacyPuzzles=Array(LabDiscipline.sorting.levels.prefix(12))
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

        for puzzle in LabDiscipline.sorting.levels {
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

        // Check useful geometry invariants, not an approved-looking sequence
        // of arbitrary heights. The complete visual result still needs review.
        let capacities=(1...6).flatMap {Array(repeating:$0,count:4)}
        let profiles=LabBoardLayout.profiles(capacities:capacities)
        let vessels=LabBoardLayout.vessels(profiles:profiles,capacities:capacities,move:nil,time:0,tilt:0,cutoffTilt:nil,cutoffElapsed:0,returnElapsed:nil)
        for (index,vessel) in vessels.enumerated() {
            let marks=[vessel.marks.x,vessel.marks.y,vessel.marks.z,vessel.marks.w,vessel.shape.y,vessel.shape.z].filter {$0>=0}
            if marks.count != capacities[index] {failures.append("graduation count does not match capacity")}
        }
        let unitVolumes=zip(profiles,capacities).map {$0.usableVolume/Float($1)}
        if unitVolumes.contains(where:{abs($0-unitVolumes[0])>0.0001}) {
            failures.append("vessels lost equal physical unit volume")
        }
        for shape in 0..<4 {
            let family=(0..<6).map {profiles[$0*4+shape]}
            if family.contains(where:{abs($0.depthScale-1)>0.0001}) {
                failures.append("capacity flattened a round opening")
            }
            for (a,b) in zip(family,family.dropFirst()) {
                if a.height >= b.height || a.radii.max()! >= b.radii.max()! {
                    failures.append("capacity does not grow in height and width")
                }
            }
            if family[0].height/family[3].height<0.45 || family[0].radii.max()!/family[3].radii.max()!<0.65 {
                failures.append("one-unit vessel is too small relative to four units")
            }
            for profile in family {
                for fraction:Float in [0.05,0.25,0.5,0.75,1] {
                    let volume=profile.usableVolume*fraction
                    if abs(profile.volume(at:profile.height(for:volume))-volume)>0.0001 {
                        failures.append("fill height does not preserve volume")
                    }
                }
            }
        }

        printFailures(failures)
    }

    private static func printFailures(_ failures:[String]) {
        if failures.isEmpty {print("PASS: complexity model, solvers, valve rules, and save migration")}
        else {for failure in failures {fputs("FAIL: \(failure)\n",stderr)};exit(1)}
    }
}
