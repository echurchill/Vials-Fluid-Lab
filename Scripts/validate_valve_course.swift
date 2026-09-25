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
            check(board.detail.contains("key"),"Valve detail does not identify its physical lid keys")
            check(board.initial.behavior == .sorting,"Valve board did not enter Sorting rules")
            check(board.initial.capacities==source.vials.map(\.capacity),"Valve capacities changed during adaptation")
            check(board.initial.rules==source.vials.map {$0.rule == .receiveOnly ? .receiveOnly:.normal},"Valve rules changed during adaptation")
            check(board.initial.stacks.indices.allSatisfy {index in
                guard source.vials[index].rule == .receiveOnly else {return board.initial.valvePigment(index)==nil}
                return board.initial.valvePigment(index)==source.vials[index].topFluid.map {pigment($0)}
            },"Valve pigment keys changed during adaptation")
            var expectedLayers=source.vials.map {$0.fluids.map(pigment)}
            if number==1 {
                expectedLayers[1].append(contentsOf:expectedLayers[2]);expectedLayers[2]=[]
                check(board.initial.stacks[2].isEmpty && board.initial.valvePigment(2)==0,"Teaching valve does not start empty with a Tide key")
            }
            check(layers(board.initial)==expectedLayers,"Valve colors or layer order changed outside the accepted empty-start teaching layout")
            check(layers(board.initial).flatMap {$0}.sorted()==source.vials.flatMap {$0.fluids.map(pigment)}.sorted(),"Valve pigment inventory changed during adaptation")
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
        check(session.notice.contains("empty Tide valve"),"Valve Basics 1 does not teach the empty physical lid")
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

        let emptyKeyed=LabBoardState(layers:[[0],[1],[]],capacities:[1,1,1],
            rules:[.normal,.normal,.receiveOnly],valvePigments:[nil,nil,1])
        check(emptyKeyed.stacks[2].isEmpty && emptyKeyed.valvePigment(2)==1,"An empty valve lost its independent pigment key")
        check(emptyKeyed.move(from:0,to:2)==nil,"A keyed lid accepted the wrong pigment")
        let matching=emptyKeyed.move(from:1,to:2)!
        check(emptyKeyed.applying(matching)?.stacks[2].count==1,"A keyed lid rejected its matching pigment")
        let encoded=try JSONEncoder().encode(emptyKeyed),decoded=try JSONDecoder().decode(LabBoardState.self,from:encoded)
        check(decoded==emptyKeyed,"An empty valve's pigment key did not survive save/restore")

        print("PASS Valve catalog: all 15 boards preserve capacity/rules/inventory; Level 1 uses the accepted empty keyed valve")
        print("PASS Valve solver: all 15 boards solve under keyed-lid rules")
        print("PASS Valve model: empty starts, wrong-color rejection, matching-color acceptance and key persistence")
        print("PASS Valve session: progressive lid guidance, pour, checkpoint/restore and sub-course switching")
    }
}
