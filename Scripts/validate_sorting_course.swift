import Foundation
import Metal
import Darwin

@main @MainActor struct ValidateSortingCourse {
    static func check(_ condition:@autoclosure()->Bool,_ message:String) {
        precondition(condition(),message)
    }

    static func finishClassicPour(_ session:FluidBoardSession) {
        for _ in 0..<200 where session.busy {session.advanceClassic(deltaTime:0.05)}
        check(!session.busy,"Classic test pour did not finish")
    }

    static func main() throws {
        let requested=Set(CommandLine.arguments.dropFirst().compactMap(Int.init))
        let numbers=requested.isEmpty ? Array(1...LabSortingCourseBoard.levelCount):requested.sorted()
        var routes=[[LabBoardMove]]()
        for number in numbers {
            print("Checking frozen Sorting Course level \(number)…",terminator:"")
            fflush(stdout)
            guard let board=LabSortingCourseBoard.level(number),let profile=LabSortingCourseBoard.sourceProfile(number) else {
                preconditionFailure("Missing Sorting Course level \(number)")
            }
            let source=VialLevelGenerator.generate(mode:profile.difficulty.originalMode,number:profile.number,generationVariant:profile.variant)
            let expected=LabBoardState.adapting(source,discovery:number.isMultiple(of:5))
            check(board.initial==expected,"Frozen level \(number) drifted from its accepted source")
            check(board.isDiscoveryLevel==number.isMultiple(of:5),"Discovery cadence changed at level \(number)")
            check(board.initial.behavior == (board.isDiscoveryLevel ? .discovery:.sorting),"Level \(number) has the wrong rules")
            check((board.initial.knownParcels != nil)==board.isDiscoveryLevel,"Level \(number) has the wrong visibility profile")
            if board.isDiscoveryLevel {
                check(board.initial.knownParcels==Set(board.initial.stacks.compactMap(\.last)),"Discovery level \(number) did not expose exactly its top units")
            }
            guard let route=board.initial.solution(limit:1_500_000) else {
                preconditionFailure("Frozen level \(number) has no Lab-engine solution")
            }
            check(route.reduce(board.initial) {$0.applying($1)!}.solved,"Route did not solve level \(number)")
            routes.append(route)
            print(" \(route.count) moves")
            fflush(stdout)
        }
        if !requested.isEmpty {
            print("PASS selected frozen Sorting Course levels: \(numbers.map(String.init).joined(separator:", "))")
            return
        }

        let first=LabSortingCourseBoard.level(1)!
        let session=FluidBoardSession(defaults:nil,device:nil,restoredSave:.init(presentation:.classic,puzzle:.crossCurrents,journeyMode:true))
        session.changeSortingCourseBoard(first)
        check(session.isSortingCourse && !session.isEndlessSorting && !session.isValveCourse && !session.journeyMode,"Sorting Course did not replace the prior context")
        check(session.boardID==first.saveKey && session.boardHeader=="SORTING COURSE","Sorting Course identity is incorrect")
        check(session.boardProgressSummary=="0 / 50 complete","Fresh course progress is incorrect")
        session.changePace(.quick)
        check(session.effectiveSpeed==2.4,"Sorting Course Quick pacing is not aligned with Endless")

        // Helper vessels are first-class Lab containers, but adding/upgrading
        // them is an undoable board action rather than a scored pour.
        check(session.supportsHelpers && session.canAddHelper,"Sorting Course did not offer helpers")
        session.addHelper()
        let helper=session.state.helpers[0]
        check(session.state.helperName(helper)=="Tea cup" && session.state.capacity(helper)==1,"The first helper is not a one-unit tea cup")
        check(session.moveCount==0 && session.canUndo,"Adding a helper changed the move count or was not undoable")
        session.upgradeHelper(helper);session.upgradeHelper(helper)
        check(session.state.helperName(helper)=="Water jug" && session.state.capacity(helper)==3,"Helper upgrades did not stop at the three-unit jug")
        check(session.moveCount==0 && !session.state.canUpgradeHelper(helper),"Helper upgrades changed the move count or exceeded the cap")
        let assistedSave=try JSONDecoder().decode(LabComparisonSave.self,from:session.checkpointData())
        let assistedGame=assistedSave.games[first.saveKey]!
        check(assistedGame.state.hasHelpers && assistedGame.actionCount==3 && assistedGame.moveCount==0,"Helper metadata/history did not persist")
        session.undo();session.undo();session.undo()
        check(!session.state.hasHelpers && session.moveCount==0 && !session.canUndo,"Undo did not remove the upgrades and helper in order")

        var helperState=first.initial.addingHelper()!
        let smallHelper=helperState.helpers[0]
        let intoHelper=helperState.stacks.indices.compactMap {helperState.move(from:$0,to:smallHelper)}.first!
        helperState=helperState.applying(intoHelper)!
        check(!helperState.solved && !helperState.stacks[smallHelper].isEmpty,"A filled helper incorrectly counted toward the win")
        guard let helperRoute=helperState.solution(limit:1_500_000) else {preconditionFailure("Hint solver could not recover from a used helper")}
        let helperFinish=helperRoute.reduce(helperState) {$0.applying($1)!}
        check(helperFinish.solved && helperFinish.stacks[smallHelper].isEmpty,"Hint route did not empty the helper before winning")

        var sharedHelper=LabBoardState.firstSort.addingHelper()!
        let sharedIndex=sharedHelper.helpers[0]
        sharedHelper=sharedHelper.upgradingHelper(sharedIndex)!.upgradingHelper(sharedIndex)!
        var queue=LabPourQueue()
        let sources=sharedHelper.stacks.indices.filter {$0 != sharedIndex && !sharedHelper.stacks[$0].isEmpty}
        var sharedPair=false
        pairSearch: for firstSource in sources {
            guard let firstArrival=queue.move(from:firstSource,to:sharedIndex,state:sharedHelper),queue.reserve(firstArrival,state:sharedHelper) else {continue}
            for secondSource in sources where secondSource != firstSource {
                if let secondArrival=queue.move(from:secondSource,to:sharedIndex,state:sharedHelper),queue.reserve(secondArrival,state:sharedHelper) {
                    sharedPair=true;break pairSearch
                }
            }
            queue=LabPourQueue()
        }
        check(sharedPair && queue.items.count==2,"Could not reserve two compatible pours into a helper")
        check(queue.projected(sharedHelper).stacks[sharedIndex].count<=3,"Concurrent helper reservations exceeded capacity")

        var discoveryState=LabSortingCourseBoard.level(5)!.initial.addingHelper()!
        let discoveryHelper=discoveryState.helpers[0]
        let discoveryMove=discoveryState.stacks.indices.compactMap {discoveryState.move(from:$0,to:discoveryHelper)}.first!
        discoveryState=discoveryState.applying(discoveryMove)!
        check(discoveryMove.parcels.allSatisfy(discoveryState.isKnown),"Discovery knowledge did not travel through a helper")

        let move=routes[0][0]
        check(session.begin(move,automaticClock:false),"Could not start a Sorting Course pour")
        finishClassicPour(session)
        let savedAfterMove=try JSONDecoder().decode(LabComparisonSave.self,from:session.checkpointData())
        check(savedAfterMove.sortingCourseBoard==first && savedAfterMove.games[first.saveKey]?.state==session.state,"Sorting Course progress was not checkpointed")

        let restored=FluidBoardSession(defaults:nil,device:nil,restoredSave:savedAfterMove)
        check(restored.sortingCourseBoard==first && restored.moveCount==1,"Sorting Course did not restore")
        let discovery=LabSortingCourseBoard.level(5)!
        restored.changeSortingCourseBoard(discovery)
        check(restored.boardHeader=="SORTING DISCOVERY" && restored.learningTopics==[.discovery],"Fifth-level Discovery presentation is missing")
        restored.changeDiscipline(.sorting)
        check(!restored.isSortingCourse && restored.puzzle.discipline == .sorting,"Could not return to the authored Sorting Lab")
        let switched=try JSONDecoder().decode(LabComparisonSave.self,from:restored.checkpointData())
        check(switched.sortingCourseBoard == nil && switched.games[first.saveKey]?.state==savedAfterMove.games[first.saveKey]?.state,"Leaving the course lost or overwrote progress")

        print("PASS Sorting Course: 50 frozen source-matched and Lab-solvable boards")
        print("PASS cadence: every fifth level through 50 uses persistent Discovery knowledge")
        print("PASS session: navigation, Quick pace, checkpoint/restore, progress isolation and authored-lab escape")
        print("PASS helpers: add/upgrade/undo/save, required-empty win, solver route and Discovery identity")
    }
}
