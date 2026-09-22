import Foundation
import Metal

@main @MainActor struct ValidateEndlessSorting {
    static func check(_ condition:@autoclosure()->Bool,_ message:String) {
        precondition(condition(),message)
    }

    static func pigment(_ fluid:Fluid)->Int {
        switch fluid {
        case .tide:0
        case .ember:1
        case .fern:2
        case .petal:3
        case .sun:4
        case .cream:5
        case .violet:6
        case .mint:7
        case .ruby:8
        case .cobalt:9
        case .lime:10
        case .pearl:11
        }
    }

    static func layers(_ state:LabBoardState)->[[Int]] {
        state.stacks.map { stack in stack.map { state.colors[$0] } }
    }

    static func finishClassicPour(_ session:FluidBoardSession) {
        for _ in 0..<200 where session.busy {session.advanceClassic(deltaTime:0.05)}
        check(!session.busy,"Classic test pour did not finish")
    }

    static func main() throws {
        let samples:[(LabEndlessDifficulty,Int,Int)]=[
            (.easy,1,0),(.easy,14,3),(.medium,8,2),(.hard,12,4)
        ]
        for (difficulty,number,variant) in samples {
            let source=VialLevelGenerator.generate(
                mode:difficulty.originalMode,
                number:number,
                generationVariant:variant
            )
            let board=LabEndlessBoard.generated(
                difficulty:difficulty,
                number:number,
                generationVariant:variant
            )
            check(board.number==source.number,"Level number changed during adaptation")
            check(board.generationVariant==source.generationVariant,"Generation variant changed during adaptation")
            check(board.initial.behavior == .sorting,"Generated board did not enter Sorting rules")
            check(board.initial.capacities==source.vials.map(\.capacity),"Vial capacities changed during adaptation")
            check(board.initial.rules==source.vials.map {$0.rule == .receiveOnly ? .receiveOnly:.normal},"Vial rules changed during adaptation")
            check(layers(board.initial)==source.vials.map {$0.fluids.map(pigment)},"Fluid colors or layer order changed during adaptation")
            check(board.initial.stacks.indices.allSatisfy { index in
                board.initial.stacks[index].count == source.vials[index].fluids.count
            },"Fluid volume changed during adaptation")
        }

        let board=LabEndlessBoard.generated(difficulty:.easy,number:1)
        let route=board.initial.solution(limit:800_000)
        check(route != nil && !route!.isEmpty,"Adapted Easy 1 has no Lab-engine solution")
        let solved=route!.reduce(board.initial) {state,move in state.applying(move)!}
        check(solved.solved,"Lab-engine route does not solve adapted Easy 1")

        let session=FluidBoardSession(
            defaults:nil,
            device:nil,
            restoredSave:.init(presentation:.classic,puzzle:.crossCurrents,journeyMode:true)
        )
        session.changeEndlessBoard(board)
        check(session.isEndlessSorting && !session.journeyMode,"Endless did not replace Journey context")
        check(session.discipline == .sorting && session.boardID == board.saveKey,"Endless board identity is incorrect")
        check(session.boardTitle == "Easy 1" && session.learningTopics.isEmpty,"Endless board metadata leaked an authored lesson")
        check(session.state == board.initial,"Endless board did not start from the adapted state")
        session.changePace(.quick)
        check(session.effectiveSpeed==2.4,"Endless Quick pacing target changed")
        session.changePace(.relaxed)
        check(session.effectiveSpeed==1,"Endless Relaxed pacing changed")
        session.changePace(.quick)

        let first=route!.first!
        check(session.begin(first,automaticClock:false),"Could not start a Lab-engine pour on Endless")
        finishClassicPour(session)
        check(session.moveCount==1 && session.state==board.initial.applying(first),"Endless pour did not commit")

        let checkpoint=try session.checkpointData()
        let saved=try JSONDecoder().decode(LabComparisonSave.self,from:checkpoint)
        check(saved.endlessBoard==board,"Endless selection was not checkpointed")
        check(saved.games[board.saveKey]?.state==session.state,"Endless progress was not checkpointed")
        let restored=FluidBoardSession(defaults:nil,device:nil,restoredSave:saved)
        check(restored.endlessBoard==board && restored.state==session.state && restored.moveCount==1,"Endless selection or progress did not restore")

        restored.changeDiscipline(.sorting)
        check(!restored.isEndlessSorting && restored.puzzle.discipline == .sorting,"Could not return from Endless to the authored Sorting Lab")
        check(restored.effectiveSpeed==LabBoardPace.quick.speed,"Endless pacing leaked into the authored labs")
        check(restored.state != board.initial.applying(first),"Endless progress overwrote the authored Sorting board")
        let switched=try JSONDecoder().decode(LabComparisonSave.self,from:restored.checkpointData())
        check(switched.endlessBoard == nil,"Authored-lab selection still restores Endless")
        check(switched.games[board.saveKey]?.state==board.initial.applying(first),"Leaving Endless discarded its progress")

        print("PASS Endless adapter: deterministic metadata, capacities, rules, colors, layers and volume")
        print("PASS Endless session: Lab-engine solve/pour, checkpoint/restore and authored-lab escape")
    }
}
