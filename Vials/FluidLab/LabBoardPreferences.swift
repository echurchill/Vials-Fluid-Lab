import Foundation

enum LabBoardPresentation:String,CaseIterable,Codable {
    case classic,fluid2D,fluid
    var title:String { switch self { case .classic:"Classic";case .fluid2D:"2D Fluid";case .fluid:"3D Fluid" } }
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
    case fiveStreams,tallOrder,sixfold,valveCircuit
    var title:String {
        switch self { case .firstSort:"First sort";case .crossCurrents:"Cross currents";case .lastDrops:"Last drops";case .greenArrival:"Green arrival";case .tidalPool:"Tidal pool";case .glassGarden:"Glass garden";case .switchback:"Switchback";case .estuary:"Estuary";case .crossingPaths:"Crossing paths";case .deepCurrent:"Deep current";case .orchard:"Orchard";case .confluence:"Confluence";case .fiveStreams:"Five streams";case .tallOrder:"Tall order";case .sixfold:"Sixfold";case .valveCircuit:"Valve circuit" }
    }
    var number:Int { Self.allCases.firstIndex(of:self)!+1 }
    var next:Self? { number<Self.allCases.count ? Self.allCases[number]:nil }
    var detail:String {
        let state=initial,range=(state.capacities.min() ?? 0)...(state.capacities.max() ?? 0)
        var parts=["Level \(number) / \(Self.allCases.count)","\(state.stacks.count) vials","\(Set(state.colors).count) colors"]
        if range.lowerBound != 4 || range.upperBound != 4 { parts.append(range.lowerBound==range.upperBound ? "\(range.lowerBound) units":"\(range.lowerBound)–\(range.upperBound) units") }
        let valves=state.rules.filter {$0 == .receiveOnly}.count
        if valves>0 { parts.append("\(valves) fill-only") }
        return parts.joined(separator:" · ")
    }
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
        // Fixed outputs from the Original game's deterministic Hard curriculum.
        case .fiveStreams: LabBoardState(
            layers:[[1,0,3,3],[2,1,1],[4,3,4,2],[1,0,2,2,3],[2,1,3,3,0],[4,0,4],[],[]],
            capacities:[4,3,4,5,5,3,5,4])
        case .tallOrder: LabBoardState(
            layers:[[3,1,0,3,4,3],[4,1,2,1,3],[0,3,4,0,2,4],[3,4,3,0],[1,3,3],[3,1,1,2],[],[]],
            capacities:[6,5,6,4,3,4,4,5])
        case .sixfold: LabBoardState(
            layers:[[0,5,4,2],[2,4,4,3,2,5],[2,1,0,5],[5,2,2,5,0],[1,5,2,1,4],[5,3,3],[5,1,1],[2,3,4,5,2],[],[]],
            capacities:[4,6,4,5,5,3,3,5,3,6])
        // Original Hard 14 with two integrated receive-only valve targets.
        case .valveCircuit: LabBoardState(
            layers:[[1,3,3,0,0],[3],[0,3,3],[4,1,3,2,2,2],[1],[3,1,0,4,3,0],[3],[2,4,3,2,0]],
            capacities:[5,6,3,6,4,6,4,5],
            rules:[.normal,.normal,.normal,.normal,.receiveOnly,.normal,.receiveOnly,.normal])
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
    var approach:Float=0
    var time:Float=0
    static let duration:Float=7.6
    var progress:Float { min(1,max(0,(time-1.6)/3.6)) }
    var returning:Bool { time>5.4 }
    var finished:Bool { time>=Self.duration }
}

/// A disposable, exact starting board and transfer for presentation comparisons.
struct LabPourExample:Identifiable {
    let id=UUID()
    let puzzle:LabBoardPuzzle
    let state:LabBoardState
    let move:LabBoardMove
}
