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
enum LabRenderQuality:String,CaseIterable,Codable {
    case automatic,high,lowEnergy
    var title:String { switch self { case .automatic:"Automatic";case .high:"High";case .lowEnergy:"Low energy" } }
    var maximumDimension:CGFloat {
        switch self {
        case .high:1000
        case .lowEnergy:720
        case .automatic:ProcessInfo.processInfo.isLowPowerModeEnabled || ProcessInfo.processInfo.thermalState != .nominal ? 720:1000
        }
    }
}
enum LabBoardPuzzle:String,CaseIterable,Codable {
    case firstSort,crossCurrents,lastDrops,greenArrival,tidalPool,glassGarden,switchback,estuary,crossingPaths,deepCurrent,orchard,confluence
    var title:String {
        switch self { case .firstSort:"First sort";case .crossCurrents:"Cross currents";case .lastDrops:"Last drops";case .greenArrival:"Green arrival";case .tidalPool:"Tidal pool";case .glassGarden:"Glass garden";case .switchback:"Switchback";case .estuary:"Estuary";case .crossingPaths:"Crossing paths";case .deepCurrent:"Deep current";case .orchard:"Orchard";case .confluence:"Confluence" }
    }
    var number:Int { Self.allCases.firstIndex(of:self)!+1 }
    var next:Self? { number<Self.allCases.count ? Self.allCases[number]:nil }
    var detail:String { "Level \(number) / \(Self.allCases.count) · \(initial.stacks.count) vials · \(Set(initial.colors).count) colors" }
    var initial:LabBoardState {
        switch self {
        case .firstSort: .firstSort
        case .crossCurrents: LabBoardState(layers:[[0,1,0],[1,0,1],[0,1],[]])
        case .lastDrops: LabBoardState(layers:[[1,0,0,0],[0,1,1,1],[],[]])
        case .greenArrival: LabBoardState(layers:[[0,1,2,0],[],[1,1,2,1],[],[2,0,2,0],[]])
        case .tidalPool: LabBoardState(layers:[[],[1,1,2,1],[],[1,0,2,0],[],[0,2,2,0]])
        case .glassGarden: LabBoardState(layers:[[1,2,0,2],[],[2,1,1,0],[],[2,0,1,0],[]])
        case .switchback: LabBoardState(layers:[[],[0,2,0,2],[],[1,0,0,1],[],[1,2,2,1]])
        case .estuary: LabBoardState(layers:[[2,0,2,1],[],[1,2,0,1],[],[0,0,2,1],[]])
        case .crossingPaths: LabBoardState(layers:[[],[0,2,1,0],[],[2,1,2,0],[],[0,1,1,2]])
        case .deepCurrent: LabBoardState(layers:[[0,2,0,2],[],[1,2,0,1],[],[1,1,2,0],[]])
        case .orchard: LabBoardState(layers:[[],[0,1,2,1],[],[1,2,0,1],[],[0,2,2,0]])
        case .confluence: LabBoardState(layers:[[2,0,0,1],[],[1,2,1,0],[],[2,0,2,1],[]])
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
