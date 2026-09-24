import Foundation

/// A small, stable progression generated and accepted offline. Only the frozen
/// board data crosses over from the Original game; play remains in the Lab.
nonisolated struct LabSortingCourseBoard:Codable,Equatable {
    static let levelCount=25
    let number:Int
    let initial:LabBoardState

    var isDiscoveryLevel:Bool {number.isMultiple(of:5)}
    var saveKey:String {"sortingCourse.\(number)"}
    var title:String {"Level \(number)"+(isDiscoveryLevel ? " · Discovery":"")}
    var detail:String {
        let range=(initial.capacities.min() ?? 0)...(initial.capacities.max() ?? 0)
        var parts=["Course \(number) / \(Self.levelCount)","\(initial.stacks.count) vials","\(Set(initial.colors).count) colors"]
        if isDiscoveryLevel {parts.append("hidden units")}
        if range.lowerBound != 4 || range.upperBound != 4 {
            parts.append(range.lowerBound==range.upperBound ? "\(range.lowerBound) units":"\(range.lowerBound)–\(range.upperBound) units")
        }
        return parts.joined(separator:" · ")
    }

    static func level(_ number:Int)->Self? {
        guard 1...levelCount ~= number else {return nil}
        return Self(number:number,initial:initial(number))
    }

    /// Source coordinates make the offline authoring decision reproducible,
    /// but the shipping course never invokes the Original generator.
    static func sourceProfile(_ number:Int)->(difficulty:LabEndlessDifficulty,number:Int,variant:Int)? {
        let variants=[2,0,1,3,1,1,0,0,1,0,0,1,2,0,0,0,0,0,4,0,2,1,7,0,0]
        guard 1...levelCount ~= number else {return nil}
        if number<=8 {return (.easy,number,variants[number-1])}
        if number<=17 {return (.medium,number-8,variants[number-1])}
        return (.hard,number-17,variants[number-1])
    }

    private static func initial(_ number:Int)->LabBoardState {
        switch number {
        case 1:return LabBoardState(layers:[[0,2,1],[2,1,0],[1,0,2],[]],capacities:[3,3,3,3])
        case 2:return LabBoardState(layers:[[2,0,1],[1,2,0],[0,1,2],[]],capacities:[3,3,3,3])
        case 3:return LabBoardState(layers:[[0,1,2],[2,0,1],[1,2,0],[]],capacities:[3,3,3,3])
        case 4:return LabBoardState(layers:[[0,2,1],[2,1,0],[1,0,2],[]],capacities:[3,3,3,3])
        case 5:return LabBoardState(layers:[[0,2,1],[1,0,2],[2,1,0],[]],capacities:[3,3,3,3],behavior:.discovery,obscured:true)
        case 6:return LabBoardState(layers:[[2,0,1,0],[0,1,2,1],[1,2,0,2],[]],capacities:[4,4,4,4])
        case 7:return LabBoardState(layers:[[0,2,2,1],[1,0,0,2],[2,1,1,0],[]],capacities:[4,4,4,4])
        case 8:return LabBoardState(layers:[[2,1,1,0],[0,2,2,1],[1,0,0,2],[]],capacities:[4,4,4,4])
        case 9:return LabBoardState(layers:[[0,1,1,2],[2,0,1,1],[0,1,0,1],[1,2,2,1],[]],capacities:[4,4,4,4,4])
        case 10:return LabBoardState(layers:[[0,1,1,1],[1,2,0,2],[2,1,1,0],[1,0,2,1],[]],capacities:[4,4,4,4,4],behavior:.discovery,obscured:true)
        case 11:return LabBoardState(layers:[[2,0,1,0],[1,0,0,2],[0,2,2,1],[0,1,0,0],[]],capacities:[4,4,4,4,4])
        case 12:return LabBoardState(layers:[[0,1,2,1],[1,2,2,2],[2,0,1,2],[0,2,0,2],[]],capacities:[4,4,4,4,4])
        case 13:return LabBoardState(layers:[[0,2,0,2],[2,0,0,0],[1,0,2,1],[0,1,1,0],[]],capacities:[4,4,4,4,4])
        case 14:return LabBoardState(layers:[[0,2,2,2],[1,0,2,2],[2,1,0,2],[1,2,1,0],[]],capacities:[4,4,4,4,4])
        case 15:return LabBoardState(layers:[[2,1,2,1],[0,2,0,2],[0,3,1,2],[2,0,2,3],[1,2,3,3],[]],capacities:[4,4,4,4,4,4],behavior:.discovery,obscured:true)
        case 16:return LabBoardState(layers:[[1,3,2,1],[3,2,3,2],[0,1,2,0],[1,3,3,3],[3,0,0,3],[]],capacities:[4,4,4,4,4,4])
        case 17:return LabBoardState(layers:[[3,2,3,1],[1,3,0,1],[2,1,1,0],[1,0,2,2],[3,1,0,1],[]],capacities:[4,4,4,4,4,4])
        case 18:return LabBoardState(layers:[[1,0,2],[0,2,3,3,1],[1,0,2,1,2],[0,1,0,2,3],[],[]],capacities:[3,5,5,5,4,3])
        case 19:return LabBoardState(layers:[[3,0,3,1,3],[1,3,3],[1,0,2,0],[2,0,2,0,1],[],[]],capacities:[5,3,4,5,3,3])
        case 20:return LabBoardState(layers:[[2,1,2],[0,2,0,0,1],[3,1,3,2,2],[0,1,3,1],[],[]],capacities:[3,5,5,4,5,4],behavior:.discovery,obscured:true)
        case 21:return LabBoardState(layers:[[1,0,1],[0,3,0,3],[0,3,2,1,0],[2,3,1,3,2],[],[]],capacities:[3,4,5,5,5,4])
        case 22:return LabBoardState(layers:[[3,0,3,2,2],[1,2,3,0],[0,1,3],[1,3,1,0,0],[],[]],capacities:[5,4,3,5,3,4])
        case 23:return LabBoardState(layers:[[3,0,1,0,2],[1,2,0],[0,3,3],[3,0,3,1,2],[],[]],capacities:[5,3,3,5,4,4])
        case 24:return LabBoardState(layers:[[4,3,4,2,2],[2,0,3,0,4],[4,1,3],[0,3,0],[4,1,4,4],[1,2,4,2],[],[]],capacities:[5,5,3,3,4,4,3,4])
        case 25:return LabBoardState(layers:[[1,0,3,3],[2,1,1],[4,3,4,2],[1,0,2,2,3],[2,1,3,3,0],[4,0,4],[],[]],capacities:[4,3,4,5,5,3,5,4],behavior:.discovery,obscured:true)
        default:preconditionFailure("Invalid Sorting Course level")
        }
    }
}
