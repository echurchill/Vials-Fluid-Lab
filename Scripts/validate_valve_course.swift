import Foundation
import Metal

@main @MainActor struct ValidateValveCourse {
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
        check(!session.busy,"Classic valve-course test pour did not finish")
    }

    static func main() async throws {
        for number in 1...LabValveBoard.levelCount {
            guard let source=VialAnchorCatalog.level(mode:.experiments,number:number),
                  let board=LabValveBoard.generated(number:number) else {
                preconditionFailure("Valve course level \(number) was not generated")
            }
            check(board.number==source.number,"Valve level number changed during adaptation")
            check(board.initial.behavior == .sorting,"Valve board did not enter Sorting rules")
            check(board.initial.capacities==source.vials.map(\.capacity),"Valve capacities changed during adaptation")
            check(board.initial.rules==source.vials.map {$0.rule == .receiveOnly ? .receiveOnly:.normal},"Valve rules changed during adaptation")
            check(layers(board.initial)==source.vials.map {$0.fluids.map(pigment)},"Valve colors or layer order changed during adaptation")
            check(board.initial.stacks.indices.allSatisfy {index in
                board.initial.stacks[index].count==source.vials[index].fluids.count
            },"Valve fluid volume changed during adaptation")
            let expectedValves=number>=8 ? 2:1
            check(board.initial.rules.filter {$0 == .receiveOnly}.count==expectedValves,"Valve count changed for level \(number)")
            guard let route=board.initial.solution(limit:800_000) else {
                preconditionFailure("Valve course level \(number) has no Lab-engine solution")
            }
            let solved=route.reduce(board.initial) {state,move in state.applying(move)!}
            check(solved.solved,"Lab-engine route did not solve valve level \(number)")
        }

        let board=LabValveBoard.generated(number:1)!
        let route=board.initial.solution(limit:800_000)!
        let session=FluidBoardSession(
            defaults:nil,
            device:nil,
            restoredSave:.init(presentation:.classic,pace:.quick,puzzle:.crossCurrents,journeyMode:true)
        )
        session.changeValveBoard(board)
        check(session.isValveCourse && !session.isEndlessSorting && !session.journeyMode,"Valve course did not replace the prior board context")
        check(session.discipline == .sorting && session.boardID==board.saveKey,"Valve course identity is incorrect")
        check(session.boardTitle=="Valve Basics 1" && session.learningTopics == [.valves],"Valve course teaching metadata is incorrect")
        check(session.state==board.initial,"Valve course did not start from the adapted state")
        check(session.effectiveSpeed==LabBoardPace.quick.speed,"Endless-only pacing leaked into the Valve Course")

        let first=route.first!
        check(session.begin(first,automaticClock:false),"Could not start a Lab-engine valve pour")
        finishClassicPour(session)
        check(session.moveCount==1 && session.state==board.initial.applying(first),"Valve course pour did not commit")

        let checkpoint=try session.checkpointData()
        let saved=try JSONDecoder().decode(LabComparisonSave.self,from:checkpoint)
        check(saved.valveBoard==board && saved.endlessBoard==nil,"Valve selection was not checkpointed exclusively")
        check(saved.games[board.saveKey]?.state==session.state,"Valve progress was not checkpointed")
        let restored=FluidBoardSession(defaults:nil,device:nil,restoredSave:saved)
        check(restored.valveBoard==board && restored.state==session.state && restored.moveCount==1,"Valve selection or progress did not restore")

        restored.changeEndlessBoard(.generated(difficulty:.easy,number:1))
        check(restored.isEndlessSorting && !restored.isValveCourse,"Endless did not replace the Valve Course")
        restored.changeDiscipline(.sorting)
        check(!restored.isEndlessSorting && !restored.isValveCourse,"Could not return from sorting sub-courses to the authored Lab")
        let switched=try JSONDecoder().decode(LabComparisonSave.self,from:restored.checkpointData())
        check(switched.valveBoard==nil && switched.endlessBoard==nil,"Authored Lab still restores a sorting sub-course")
        check(switched.games[board.saveKey]?.state==board.initial.applying(first),"Leaving the Valve Course discarded its progress")

        let recoverable=LabBoardState(layers:[[0],[1],[]],capacities:[1,1,1],rules:[.normal,.normal,.receiveOnly],
            targets:[.init(vial:2,layers:[.init(1)])])
        let wrongMove=recoverable.move(from:0,to:2)!
        check(recoverable.solution() != nil && recoverable.applying(wrongMove)!.solution() == nil,"Hint-recovery fixture is not a recoverable dead end")
        let recovery=FluidBoardSession(defaults:nil,device:nil,restoredSave:.init(presentation:.classic,puzzle:.valveCircuit,
            games:[LabBoardPuzzle.valveCircuit.rawValue:LabBoardGame(state:recoverable)]))
        check(recovery.begin(wrongMove,automaticClock:false),"Could not enter the hint-recovery dead end")
        finishClassicPour(recovery)
        recovery.hint()
        for _ in 0..<500 where recovery.findingHint {try? await Task.sleep(for:.milliseconds(5))}
        check(!recovery.findingHint && recovery.hintUndoOffer,"A dead end did not offer Undo-to-hint recovery")
        recovery.undoUntilHintAvailable()
        for _ in 0..<500 where recovery.findingHint {try? await Task.sleep(for:.milliseconds(5))}
        check(!recovery.findingHint && recovery.moveCount==0,"Hint recovery did not rewind to the nearest solvable state")
        check(recovery.selected==1 && recovery.hintTarget==2 && !recovery.hintUndoOffer,"Hint recovery did not present the recovered hint")

        print("PASS Valve adapter: all 15 boards preserve capacities, rules, colors, layers and volume")
        print("PASS Valve solver: all 15 boards solve under Lab rules")
        print("PASS Valve session: pour, teaching, checkpoint/restore, sub-course switching and opt-in Undo-to-hint recovery")
    }
}
