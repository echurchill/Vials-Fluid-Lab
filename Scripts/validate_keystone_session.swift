import Foundation
import Metal

@main @MainActor struct ValidateKeystoneSession {
    static func require(_ condition:@autoclosure()->Bool,_ message:String) {
        if !condition() {fatalError(message)}
    }
    static func main() async {
        let defaults=UserDefaults(suiteName:"dev.vials.keystone-validation")!
        defaults.removePersistentDomain(forName:"dev.vials.keystone-validation")
        for discipline in [LabDiscipline.density,.mixing,.crossover] {
            for puzzle in discipline.levels {
                let save=LabComparisonSave(presentation:.classic,pace:.quick,puzzle:puzzle,games:[:])
                // Match the live board configuration. Experimental disciplines
                // deliberately serialize operations even though Sorting retains
                // its dependency-safe multi-pour behavior.
                let session=FluidBoardSession(defaults:defaults,device:nil,restoredSave:save,allowsConcurrentPours:true)
                require(!session.concurrentPoursEnabled,"\(puzzle.rawValue): experimental concurrency should be deterministic")
                let route=puzzle.authoredRoute(from:session.state) ?? session.state.operationSolution(limit:800_000)
                require(route != nil,"\(puzzle.rawValue): missing session route")
                session.hint()
                for _ in 0..<200 where session.findingHint {try? await Task.sleep(for:.milliseconds(5))}
                require(!session.findingHint,"\(puzzle.rawValue): hint did not finish")
                switch route!.first! {
                case .pour(let move):
                    require(session.selected==move.source && session.hintTarget==move.destination,"\(puzzle.rawValue): wrong first pour hint")
                case .activate(let activation):
                    require(session.hintApparatusID==activation.apparatusID,"\(puzzle.rawValue): wrong first apparatus hint")
                }
                for operation in route! {
                    switch operation {
                    case .pour(let move):
                        require(session.begin(move,automaticClock:false),"\(puzzle.rawValue): session rejected pour")
                        for _ in 0..<120 where session.busy {session.advanceClassic(deltaTime:0.1)}
                        require(!session.busy,"\(puzzle.rawValue): Classic pour did not finish")
                    case .activate(let activation):
                        require(session.state.canActivate(activation),"\(puzzle.rawValue): apparatus not ready")
                        session.activateApparatus(activation.apparatusID,animated:false)
                    }
                }
                require(session.solved,"\(puzzle.rawValue): session route did not solve")
                let moves=session.moveCount
                for _ in 0..<moves {session.undo()}
                require(session.state==puzzle.initial,"\(puzzle.rawValue): Undo did not restore initial state")
            }
        }

        // The 2D silhouette must use the same glass width as Classic/3D.
        // Normalizing its area to the capacity fraction collapsed one-unit
        // mixing vials into almost line-thin slivers.
        let mixingProfiles=LabBoardLayout.profiles(capacities:LabBoardPuzzle.warmBlend.initial.capacities)
        let planar=LabFluid2D(game:LabBoardGame(state:LabBoardPuzzle.warmBlend.initial))
        for index in mixingProfiles.indices {
            let y=mixingProfiles[index].height*0.5
            require(abs(planar.profiles[index].radius(y)-mixingProfiles[index].radius(at:y))<0.0001,
                "Mixing vial \(index) has mismatched 2D and 3D glass width")
        }
        for (puzzle,source,destination) in [(LabBoardPuzzle.warmBlend,0,2),(.measuredBatch,1,4)] {
            var movingPlanar=LabFluid2D(game:LabBoardGame(state:puzzle.initial))
            let dose=movingPlanar.game.state.move(from:source,to:destination)!
            require(movingPlanar.begin(dose),"\(puzzle.rawValue): 2D pour did not begin")
            for _ in 0..<1500 where movingPlanar.busy {movingPlanar.advance(deltaTime:1/60,speed:1.6)}
            require(!movingPlanar.busy && movingPlanar.game.state.stacks[destination].count==1,
                "\(puzzle.rawValue): 2D dose did not reach its chamber")
        }

        let switcher=FluidBoardSession(defaults:defaults,device:nil,
            restoredSave:LabComparisonSave(presentation:.classic,puzzle:.firstSort),allowsConcurrentPours:true)
        require(switcher.concurrentPoursEnabled,"Sorting lost concurrent pours")
        switcher.changeDiscipline(.density);require(switcher.puzzle == .heavyLanding,"Density did not open at its first level")
        switcher.changePuzzle(.threeDeep);switcher.changeDiscipline(.mixing);require(switcher.puzzle == .warmBlend,"Mixing did not open at its first level")
        switcher.changeDiscipline(.density);require(switcher.puzzle == .threeDeep,"Density did not remember its last level")
        let data=try! switcher.checkpointData(),decoded=try! JSONDecoder().decode(LabComparisonSave.self,from:data)
        require(decoded.lastPuzzles[LabDiscipline.density.rawValue]==LabBoardPuzzle.threeDeep.rawValue,"Save omitted last Density level")
        let oldJSON=Data(#"{"presentation":"classic","pace":"quick","puzzle":"againstThePour","games":{}}"#.utf8)
        require((try! JSONDecoder().decode(LabComparisonSave.self,from:oldJSON)).densitySetupVersion==0,"Old save did not request Density migration")
        let oldInverted=LabBoardState(layers:[[0,4,8],[2,6,1],[],[],[]],capacities:[3,3,3,3,3],
            densityLayers:[[.light,.medium,.heavy],[.heavy,.light,.medium],[],[],[]],behavior:.density)
        let prior=LabComparisonSave(presentation:.classic,puzzle:.againstThePour,
            games:[LabBoardPuzzle.againstThePour.rawValue:LabBoardGame(state:oldInverted),
                   LabBoardPuzzle.warmBlend.rawValue:LabBoardGame(state:LabBoardPuzzle.warmBlend.initial)],densitySetupVersion:0)
        let migrated=FluidBoardSession(defaults:nil,device:nil,restoredSave:prior,allowsConcurrentPours:true)
        require(migrated.state==LabBoardPuzzle.againstThePour.initial,"Prior inverted Density save was not replaced")
        let migrationData=try! migrated.checkpointData(),migration=try! JSONDecoder().decode(LabComparisonSave.self,from:migrationData)
        require(migration.densitySetupVersion==1,"Density setup migration was not stamped")
        require(migration.games[LabBoardPuzzle.warmBlend.rawValue]?.state==LabBoardPuzzle.warmBlend.initial,"Density migration removed Mixing progress")
        print("Keystone session validation passed for 15 experimental levels and four-lab persistence.")
    }
}
