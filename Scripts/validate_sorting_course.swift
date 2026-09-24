import Foundation
import Metal

@main @MainActor struct ValidateSortingCourse {
    static func check(_ condition:@autoclosure()->Bool,_ message:String) {
        precondition(condition(),message)
    }

    static func finishClassicPour(_ session:FluidBoardSession) {
        for _ in 0..<200 where session.busy {session.advanceClassic(deltaTime:0.05)}
        check(!session.busy,"Classic test pour did not finish")
    }

    static func main() throws {
        var routes=[[LabBoardMove]]()
        for number in 1...LabSortingCourseBoard.levelCount {
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
        }

        let first=LabSortingCourseBoard.level(1)!
        let session=FluidBoardSession(defaults:nil,device:nil,restoredSave:.init(presentation:.classic,puzzle:.crossCurrents,journeyMode:true))
        session.changeSortingCourseBoard(first)
        check(session.isSortingCourse && !session.isEndlessSorting && !session.isValveCourse && !session.journeyMode,"Sorting Course did not replace the prior context")
        check(session.boardID==first.saveKey && session.boardHeader=="SORTING COURSE","Sorting Course identity is incorrect")
        check(session.boardProgressSummary=="0 / 25 complete","Fresh course progress is incorrect")
        session.changePace(.quick)
        check(session.effectiveSpeed==2.4,"Sorting Course Quick pacing is not aligned with Endless")

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

        print("PASS Sorting Course: 25 frozen source-matched and Lab-solvable boards")
        print("PASS cadence: levels 5, 10, 15, 20 and 25 use persistent Discovery knowledge")
        print("PASS session: navigation, Quick pace, checkpoint/restore, progress isolation and authored-lab escape")
    }
}
