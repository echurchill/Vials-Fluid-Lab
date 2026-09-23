import Foundation

extension LabValveBoard {
    /// Accepted outputs from the Original experiment generator. Keeping the
    /// course fixed makes navigation immediate and progression stable; the
    /// validation suite still compares every fixture with its source board.
    nonisolated static func generated(number:Int)->Self? {
        guard 1...Self.levelCount ~= number else {return nil}
        return Self(number:number,initial:initial(number))
    }

    private nonisolated static func initial(_ number:Int)->LabBoardState {
        switch number {
        case 1:return LabBoardState(layers:[[0,0,1],[2,1],[0],[1,2,2]],capacities:[3,3,3,3],rules:[.normal,.normal,.receiveOnly,.normal])
        case 2:return LabBoardState(layers:[[2,0],[1],[0,2,2],[1,1,0]],capacities:[3,3,3,3],rules:[.normal,.receiveOnly,.normal,.normal])
        case 3:return LabBoardState(layers:[[2],[0,1],[2,2,1],[1,0,0]],capacities:[3,3,3,3],rules:[.receiveOnly,.normal,.normal,.normal])
        case 4:return LabBoardState(layers:[[1,0],[2],[0,1,1],[2,2,0]],capacities:[3,3,3,3],rules:[.normal,.receiveOnly,.normal,.normal])
        case 5:return LabBoardState(layers:[[2,2,1],[1,0,0],[2],[0,1]],capacities:[3,3,3,3],rules:[.normal,.normal,.receiveOnly,.normal])
        case 6:return LabBoardState(layers:[[2,0,0,1],[1,1],[2,2],[0,2,1,2],[2,2,2,0]],capacities:[4,4,4,4,4],rules:[.normal,.normal,.receiveOnly,.normal,.normal])
        case 7:return LabBoardState(layers:[[2,1,2,2],[2,2],[1,2,0,0],[0,0],[2,2,1,1]],capacities:[4,4,4,4,4],rules:[.normal,.receiveOnly,.normal,.normal,.normal])
        case 8:return LabBoardState(layers:[[2,2],[1,1,0,0],[0,2,1,1],[2,0,0,0],[0,0]],capacities:[4,4,4,4,4],rules:[.receiveOnly,.normal,.normal,.normal,.receiveOnly])
        case 9:return LabBoardState(layers:[[2,2],[1,0,0,1],[0,0],[0,1,0,1],[2,0,2,0]],capacities:[4,4,4,4,4],rules:[.receiveOnly,.normal,.receiveOnly,.normal,.normal])
        case 10:return LabBoardState(layers:[[1,0,2,0],[2,2],[0,1,2,1],[1,1,0,1],[1,1]],capacities:[4,4,4,4,4],rules:[.normal,.receiveOnly,.normal,.normal,.receiveOnly])
        case 11:return LabBoardState(layers:[[3,3,3],[1,2,3,2,0],[1],[1,3,2],[2,0,0],[2]],capacities:[5,5,3,3,3,4],rules:[.receiveOnly,.normal,.receiveOnly,.normal,.normal,.normal])
        case 12:return LabBoardState(layers:[[0,0,0],[3,3,3],[0,2,3,2],[2,0,3,1],[1,1,2,1],[]],capacities:[5,5,4,4,4,4],rules:[.receiveOnly,.receiveOnly,.normal,.normal,.normal,.normal])
        case 13:return LabBoardState(layers:[[2,2],[1,0,3,2,3],[1],[1,1,2,2,0],[0,3],[0,3,3,0]],capacities:[5,5,4,5,3,4],rules:[.receiveOnly,.normal,.receiveOnly,.normal,.normal,.normal])
        case 14:return LabBoardState(layers:[[0],[1,1],[3],[0,1,0,0,3],[1,2,1,2],[3,2,2,2,3]],capacities:[4,5,3,5,4,5],rules:[.receiveOnly,.receiveOnly,.normal,.normal,.normal,.normal])
        case 15:return LabBoardState(layers:[[3],[0,0,3,3],[3,1,1,2,0],[2],[1],[1,2,3]],capacities:[4,4,5,3,4,3],rules:[.normal,.normal,.normal,.receiveOnly,.receiveOnly,.normal])
        default:preconditionFailure("Invalid Valve Course level")
        }
    }
}
