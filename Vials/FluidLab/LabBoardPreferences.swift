import Foundation

enum LabBoardPresentation:String,CaseIterable,Codable {
    case classic,fluid
    var title:String { self == .classic ? "Classic":"Fluid" }
}
enum LabBoardPace:String,CaseIterable,Codable {
    case relaxed,quick
    var title:String { self == .quick ? "Quick":"Relaxed" }
    var speed:Float { self == .quick ? 1.6:1 }
}
enum LabBoardPuzzle:String,CaseIterable,Codable {
    case firstSort,crossCurrents,lastDrops
    var title:String {
        switch self { case .firstSort:"First sort";case .crossCurrents:"Cross currents";case .lastDrops:"Last drops" }
    }
    var initial:LabBoardState {
        switch self {
        case .firstSort: .firstSort
        case .crossCurrents: LabBoardState(layers:[[0,1,0],[1,0,1],[0,1],[]])
        case .lastDrops: LabBoardState(layers:[[1,0,0,0],[0,1,1,1],[],[]])
        }
    }
}
struct LabComparisonSave:Codable {
    var presentation:LabBoardPresentation = .fluid
    var pace:LabBoardPace = .relaxed
    var puzzle:LabBoardPuzzle = .firstSort
    var games:[String:LabBoardGame] = [:]
}

/// A deterministic nonparticle pour. The animation clock pauses with the game.
struct LabClassicPour {
    let move:LabBoardMove
    var time:Float=0
    static let duration:Float=7.6
    var progress:Float { min(1,max(0,(time-1.6)/3.6)) }
    var returning:Bool { time>5.4 }
    var finished:Bool { time>=Self.duration }
}
