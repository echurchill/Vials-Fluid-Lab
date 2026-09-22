import Foundation
import Metal

@main @MainActor struct ValidateJourney {
    static func check(_ condition:@autoclosure()->Bool,_ message:String) {
        precondition(condition(),message)
    }
    static func main() throws {
        let stops=LabJourney.stops,ids=Set(stops.map(\.puzzle))
        check(ids.count==stops.count,"Duplicate Journey stop")
        check(Set(stops.map {$0.puzzle.discipline})==Set(LabDiscipline.allCases),"Missing lab branch")
        var visited:Set<LabBoardPuzzle>=[],active:Set<LabBoardPuzzle>=[]
        func walk(_ puzzle:LabBoardPuzzle) {
            check(!active.contains(puzzle),"Cycle in learning path")
            if visited.contains(puzzle) {return}
            check(ids.contains(puzzle),"Dangling Journey edge")
            active.insert(puzzle)
            for next in LabJourney.stop(puzzle)!.next {walk(next)}
            active.remove(puzzle);visited.insert(puzzle)
        }
        walk(.firstSort);check(visited==ids,"Unreachable Journey stop")
        check(LabJourney.stop(.crossCurrents)!.next==[.heavyLanding,.warmBlend,.firstReveal],"Sorting fork changed")
        check(LabJourney.stop(.hiddenGarden)!.next.isEmpty,"Discovery must stay optional")
        for stop in stops {
            check(!stop.lesson.isEmpty,"Missing learning goal")
            let state=stop.puzzle.initial
            let route=stop.puzzle.authoredRoute() ?? state.operationSolution(limit:800_000)
            check(route != nil,"Unsolvable Journey stop")
            var final=state
            for move in route! {final=final.applying(move)!}
            check(final.solved,"Journey route does not solve")
        }
        let direct=FluidBoardSession(defaults:nil,device:nil,restoredSave:.init(presentation:.classic,puzzle:.crossCurrents))
        check(!direct.journeyMode && direct.nextSuggestedPuzzle == .lastDrops,"Direct lab navigation changed")
        direct.startJourney(at:.crossCurrents)
        check(direct.journeyMode && direct.nextSuggestedPuzzle==nil,"Fork must offer choices")
        direct.nextPuzzle();check(direct.puzzle == .crossCurrents,"Fork silently chose a branch")
        direct.startJourney(at:.heavyLanding)
        check(direct.discipline == .density && direct.journeyMode,"Cross-lab Journey selection failed")
        direct.changePresentation(.fluid2D);check(direct.journeyMode,"Mode switching left Journey")
        direct.changePresentation(.classic)
        let restored=try JSONDecoder().decode(LabComparisonSave.self,from:direct.checkpointData())
        check(restored.journeyMode,"Journey context not saved")
        let reloaded=FluidBoardSession(defaults:nil,device:nil,restoredSave:restored)
        check(reloaded.journeyMode && reloaded.puzzle == .heavyLanding,"Journey context not restored")
        reloaded.changeDiscipline(.density)
        check(!reloaded.journeyMode && reloaded.puzzle == .heavyLanding,"Cannot exit to same lab")
        reloaded.startJourney(at:.violetReaction);reloaded.nextPuzzle()
        check(reloaded.journeyMode && reloaded.puzzle == .splitPurple,"Mixing to Recovery bridge failed")
        reloaded.startJourney(at:.shadesOfBlue);reloaded.nextPuzzle()
        check(reloaded.puzzle == .equalPartners,"Density to combined bridge failed")
        reloaded.startJourney(at:.secondChance);reloaded.nextPuzzle()
        check(reloaded.puzzle == .equalPartners,"Recovery to combined bridge failed")
        reloaded.startJourney(at:.fullSpectrum);check(reloaded.nextSuggestedPuzzle==nil && reloaded.journeyNext.isEmpty,"Final stop loops")
        reloaded.changePuzzle(.valveCircuit);check(!reloaded.journeyMode,"Direct puzzle retained Journey context")
        let prior=reloaded.puzzle;reloaded.startJourney(at:.valveCircuit)
        check(reloaded.puzzle==prior && !reloaded.journeyMode,"Unknown Journey stop accepted")
        let starting=LabBoardPuzzle.heavyLanding.initial
        let solution=LabBoardPuzzle.heavyLanding.authoredRoute()!
        let final=solution.reduce(starting) {$0.applying($1)!}
        let progress=LabComparisonSave(presentation:.classic,puzzle:.heavyLanding,games:[LabBoardPuzzle.heavyLanding.rawValue:LabBoardGame(state:final)])
        let shared=FluidBoardSession(defaults:nil,device:nil,restoredSave:progress)
        shared.startJourney(at:.heavyLanding)
        check(shared.solved && shared.hasCompleted(.heavyLanding),"Journey reset existing lab progress")
        shared.changeDiscipline(.density);check(shared.solved,"Direct lab lost Journey completion")
        var legacy=try JSONSerialization.jsonObject(with:JSONEncoder().encode(progress)) as! [String:Any]
        legacy.removeValue(forKey:"journeyMode")
        let old=try JSONDecoder().decode(LabComparisonSave.self,from:JSONSerialization.data(withJSONObject:legacy))
        check(!old.journeyMode && old.games.mapValues(\.state)==progress.games.mapValues(\.state),"Old save migration changed progress")
        let busy=FluidBoardSession(defaults:nil,device:nil,restoredSave:.init(presentation:.classic))
        let move=busy.state.solution()!.first!
        check(busy.begin(move,automaticClock:false),"Cannot start busy-navigation test")
        busy.startJourney(at:.warmBlend)
        check(busy.puzzle == .firstSort && !busy.journeyMode,"Journey switched during a pour")
        busy.resetAllProgress()
        check(busy.journeyMode && busy.puzzle == .firstSort && !busy.hasCompleted(.heavyLanding),"Fresh reset did not restore Journey start")
        print("PASS Journey: 19 solvable/reachable stops, no cycles, optional branch, cross-lab navigation, direct lab escape, shared progress, save migration, busy guards and full reset")
    }
}
