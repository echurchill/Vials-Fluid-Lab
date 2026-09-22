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

nonisolated enum LabDiscipline:String,CaseIterable,Codable {
    case sorting,discovery,density,mixing,recovery,crossover
    var title:String {
        switch self {case .sorting:"Sorting";case .discovery:"Discovery";case .density:"Density";case .mixing:"Mixing";case .recovery:"Recovery";case .crossover:"Crossover"}
    }
    var header:String { title.uppercased()+" LAB" }
    var levels:[LabBoardPuzzle] { LabBoardPuzzle.allCases.filter {$0.discipline==self} }
}
nonisolated enum LabAuthoredStep:Equatable {
    case pour(Int,Int)
    case activate(Int)
}
nonisolated enum LabBoardPuzzle:String,CaseIterable,Codable {
    case firstSort,crossCurrents,lastDrops,greenArrival,tidalPool,glassGarden,switchback,estuary,crossingPaths,deepCurrent,orchard,confluence
    case fiveStreams,tallOrder,sixfold,valveCircuit
    case heavyLanding,threeDeep,shadesOfBlue,twinColumns,againstThePour
    case warmBlend,coolBlend,violetReaction,colorWheel,measuredBatch
    case firstReveal,peekAhead,buriedClue,thirdColor,hiddenGarden
    case splitPurple,roomForBoth,secondChance,keepEveryDrop
    case readyToBlend,oneStepHeavier,floatAgain,equalPartners,weightedOrange,layerCake,twinProducts,fullSpectrum
    var discipline:LabDiscipline {
        switch self {
        case .firstReveal,.peekAhead,.buriedClue,.thirdColor,.hiddenGarden:.discovery
        case .splitPurple,.roomForBoth,.secondChance,.keepEveryDrop:.recovery
        case .heavyLanding,.threeDeep,.shadesOfBlue,.twinColumns,.againstThePour:.density
        case .warmBlend,.coolBlend,.violetReaction,.colorWheel,.measuredBatch:.mixing
        case .readyToBlend,.oneStepHeavier,.floatAgain,.equalPartners,.weightedOrange,.layerCake,.twinProducts,.fullSpectrum:.crossover
        default:.sorting
        }
    }
    var title:String {
        switch self {
        case .firstSort:"First sort";case .crossCurrents:"Cross currents";case .lastDrops:"Last drops";case .greenArrival:"Green arrival";case .tidalPool:"Tidal pool";case .glassGarden:"Glass garden";case .switchback:"Switchback";case .estuary:"Estuary";case .crossingPaths:"Crossing paths";case .deepCurrent:"Deep current";case .orchard:"Orchard";case .confluence:"Confluence";case .fiveStreams:"Five streams";case .tallOrder:"Tall order";case .sixfold:"Sixfold";case .valveCircuit:"Valve circuit"
        case .firstReveal:"First reveal";case .peekAhead:"Peek ahead";case .buriedClue:"Buried clue";case .thirdColor:"Third color";case .hiddenGarden:"Hidden garden"
        case .splitPurple:"Split purple";case .roomForBoth:"Room for both";case .secondChance:"Second chance";case .keepEveryDrop:"Keep every drop"
        case .heavyLanding:"Heavy landing";case .threeDeep:"Three deep";case .shadesOfBlue:"Shades of blue";case .twinColumns:"Twin columns";case .againstThePour:"Against the pour"
        case .warmBlend:"Warm blend";case .coolBlend:"Cool blend";case .violetReaction:"Violet reaction";case .colorWheel:"Color wheel";case .measuredBatch:"Measured batch"
        case .readyToBlend:"Ready to blend";case .oneStepHeavier:"One step heavier";case .floatAgain:"Float again";case .equalPartners:"Equal partners";case .weightedOrange:"Weighted orange";case .layerCake:"Layer cake";case .twinProducts:"Twin products";case .fullSpectrum:"Full spectrum"
        }
    }
    var instruction:String {discipline == .discovery ? "Pour known colors to reveal what is below. Discoveries stay known.":(discipline == .sorting ? "Tap a filled vial, then a matching color or an empty vial.":"Match the outlined target vials.")}
    var number:Int { discipline.levels.firstIndex(of:self)!+1 }
    var next:Self? { let levels=discipline.levels;return number<levels.count ? levels[number]:nil }
    var detail:String {
        let state=initial,range=(state.capacities.min() ?? 0)...(state.capacities.max() ?? 0)
        var parts=["Level \(number) / \(discipline.levels.count)","\(state.stacks.count) vials","\(Set(state.colors).count) colors"]
        if state.behavior.settlesByDensity {parts.append("\(Set(state.densities).count) densities")}
        if !state.targets.isEmpty {parts.append(state.targets.count==1 ? "1 target":"\(state.targets.count) targets")}
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
        case .firstReveal: LabBoardState(layers:[[0,1],[1,0],[],[]],capacities:[2,2,2,2],behavior:.discovery,obscured:true)
        case .peekAhead: LabBoardState(layers:[[0,1],[1,0],[0,1],[]],capacities:[3,3,3,3],behavior:.discovery,obscured:true)
        case .buriedClue: LabBoardState(layers:[[0,1,0],[1,0,1],[],[]],capacities:[3,3,3,3],behavior:.discovery,obscured:true)
        case .thirdColor: LabBoardState(layers:[[0,1],[1,2],[2,0],[],[]],capacities:[2,2,2,2,2],behavior:.discovery,obscured:true)
        case .hiddenGarden: LabBoardState(layers:[[0,1,2],[2,0,1],[1,2,0],[],[]],capacities:[3,3,3,3,3],behavior:.discovery,obscured:true)
        case .splitPurple: LabBoardState(layers:[[6,6],[],[]],capacities:[2,1,1],rules:[.normal,.sourceOnly,.sourceOnly],behavior:.mixing,
            targets:[.init(vial:1,layers:[.init(0)]),.init(vial:2,layers:[.init(8)])],apparatus:[.separator(input:0,outputs:[1,2])])
        case .roomForBoth: LabBoardState(layers:[[1,1],[8],[],[]],capacities:[2,1,1,1],rules:[.normal,.sourceOnly,.sourceOnly,.normal],behavior:.mixing,
            targets:[.init(vial:1,layers:[.init(8)]),.init(vial:2,layers:[.init(4)]),.init(vial:3,layers:[.init(8)])],apparatus:[.separator(input:0,outputs:[1,2])])
        case .secondChance: LabBoardState(layers:[[6,6],[4],[],[],[]],capacities:[2,1,1,1,2],rules:[.normal,.normal,.sourceOnly,.sourceOnly,.sourceOnly],behavior:.mixing,
            targets:[.init(vial:2,layers:[.init(0)]),.init(vial:4,layers:[.init(1),.init(1)])],apparatus:[.separator(input:0,outputs:[2,3]),.mixer(id:1,inputs:[3,1],output:4)])
        case .keepEveryDrop: LabBoardState(layers:[[6,6],[1,1],[],[],[],[],[],[]],capacities:[2,2,1,1,1,1,2,2],rules:[.normal,.normal,.sourceOnly,.sourceOnly,.sourceOnly,.sourceOnly,.sourceOnly,.normal],behavior:.mixing,
            targets:[.init(vial:6,layers:[.init(2),.init(2)]),.init(vial:7,layers:[.init(8),.init(8)])],apparatus:[.separator(input:0,outputs:[2,3]),.separator(id:1,input:1,outputs:[4,5]),.mixer(id:2,inputs:[2,5],output:6)])
        case .heavyLanding: LabBoardState(
            layers:[[0],[8],[]],capacities:[2,2,2],
            densityLayers:[[.light],[.heavy],[]],behavior:.density,
            targets:[LabVialTarget(vial:2,layers:[.init(8,.heavy),.init(0,.light)])])
        case .threeDeep: LabBoardState(
            layers:[[0],[4],[8],[]],capacities:[3,3,3,3],
            densityLayers:[[.light],[.medium],[.heavy],[]],behavior:.density,
            targets:[LabVialTarget(vial:3,layers:[.init(8,.heavy),.init(4,.medium),.init(0,.light)])])
        case .shadesOfBlue: LabBoardState(
            layers:[[0],[0],[0],[]],capacities:[3,3,3,3],
            densityLayers:[[.light],[.medium],[.heavy],[]],behavior:.density,
            targets:[LabVialTarget(vial:3,layers:[.init(0,.heavy),.init(0,.medium),.init(0,.light)])])
        case .twinColumns: LabBoardState(
            layers:[[8,2],[4,0],[],[],[]],capacities:[2,2,2,2,2],
            densityLayers:[[.heavy,.heavy],[.medium,.light],[],[],[]],behavior:.density,
            targets:[LabVialTarget(vial:2,layers:[.init(8,.heavy),.init(0,.light)]),LabVialTarget(vial:3,layers:[.init(2,.heavy),.init(4,.medium)])])
        case .againstThePour: LabBoardState(
            layers:[[8,2],[4,1],[],[],[0,6]],capacities:[3,3,3,3,3],
            densityLayers:[[.heavy,.heavy],[.medium,.medium],[],[],[.light,.light]],behavior:.density,
            targets:[LabVialTarget(vial:2,layers:[.init(8,.heavy),.init(4,.medium),.init(0,.light)]),LabVialTarget(vial:3,layers:[.init(2,.heavy),.init(1,.medium),.init(6,.light)])])
        case .warmBlend: Self.mixingLevel(first:8,second:4,product:1)
        case .coolBlend: Self.mixingLevel(first:4,second:0,product:2)
        case .violetReaction: Self.mixingLevel(first:0,second:8,product:6)
        case .colorWheel: LabBoardState(
            layers:[[8,8],[4,4],[0,0],[],[],[],[],[],[]],capacities:[2,2,2,1,1,2,2,2,2],
            rules:[.normal,.normal,.normal,.normal,.normal,.sourceOnly,.normal,.normal,.normal],behavior:.mixing,
            targets:[LabVialTarget(vial:6,layers:[.init(1),.init(1)]),LabVialTarget(vial:7,layers:[.init(2),.init(2)]),LabVialTarget(vial:8,layers:[.init(6),.init(6)])],
            apparatus:[.mixer(inputs:[3,4],output:5)])
        case .measuredBatch: LabBoardState(
            layers:[[8,8],[4,4,4],[0],[],[],[],[],[]],capacities:[2,3,1,1,1,2,4,2],
            rules:[.normal,.normal,.normal,.normal,.normal,.sourceOnly,.normal,.normal],behavior:.mixing,
            targets:[LabVialTarget(vial:6,layers:Array(repeating:.init(1),count:4)),LabVialTarget(vial:7,layers:Array(repeating:.init(2),count:2))],
            apparatus:[.mixer(inputs:[3,4],output:5)])
        case .readyToBlend: LabBoardState(
            layers:[[8],[4],[]],capacities:[1,1,2],rules:[.normal,.normal,.sourceOnly],behavior:.crossover,
            targets:[.init(vial:2,layers:[.init(1),.init(1)])],apparatus:[.mixer(inputs:[0,1],output:2)])
        case .oneStepHeavier,.floatAgain: LabBoardState(
            layers:[[0],[],[]],capacities:[1,1,1],behavior:.crossover,
            targets:[.init(vial:2,layers:[.init(0,self == .oneStepHeavier ? .heavy:.light)])],
            apparatus:[.modifier(chamber:1,direction:self == .oneStepHeavier ? .heavier:.lighter)])
        case .equalPartners: LabBoardState(
            layers:[[8],[4],[],[],[],[],[]],capacities:[1,1,1,1,1,2,2],
            rules:[.normal,.normal,.normal,.normal,.normal,.sourceOnly,.normal],densityLayers:[[.light],[.medium],[],[],[],[],[]],behavior:.crossover,
            targets:[LabVialTarget(vial:6,layers:[.init(1,.medium),.init(1,.medium)])],
            apparatus:[.modifier(id:0,chamber:2,direction:.heavier),.mixer(id:1,inputs:[3,4],output:5)])
        case .weightedOrange: LabBoardState(
            layers:[[8],[4],[],[],[],[],[]],capacities:[1,1,1,1,2,2,2],
            rules:[.normal,.normal,.normal,.normal,.sourceOnly,.normal,.normal],behavior:.crossover,
            targets:[LabVialTarget(vial:6,layers:[.init(1,.heavy),.init(1,.heavy)])],
            apparatus:[.mixer(id:0,inputs:[2,3],output:4),.modifier(id:1,chamber:5,direction:.heavier)])
        case .layerCake: LabBoardState(
            layers:[[8],[4],[0],[],[],[],[],[]],capacities:[1,1,1,1,1,2,2,3],
            rules:[.normal,.normal,.normal,.normal,.normal,.sourceOnly,.normal,.normal],densityLayers:[[.medium],[.medium],[.light],[],[],[],[],[]],behavior:.crossover,
            targets:[LabVialTarget(vial:7,layers:[.init(1,.heavy),.init(1,.heavy),.init(0,.light)])],
            apparatus:[.mixer(id:0,inputs:[3,4],output:5),.modifier(id:1,chamber:6,direction:.heavier)])
        case .twinProducts: LabBoardState(
            layers:[[8],[4,4],[0],[],[],[],[],[],[],[]],capacities:[1,2,1,1,1,2,2,2,2,2],
            rules:[.normal,.normal,.normal,.normal,.normal,.sourceOnly,.normal,.normal,.normal,.normal],behavior:.crossover,
            targets:[LabVialTarget(vial:8,layers:[.init(1,.heavy),.init(1,.heavy)]),LabVialTarget(vial:9,layers:[.init(2,.light),.init(2,.light)])],
            apparatus:[.mixer(id:0,inputs:[3,4],output:5),.modifier(id:1,chamber:6,direction:.heavier),.modifier(id:2,chamber:7,direction:.lighter)])
        case .fullSpectrum: LabBoardState(
            layers:[[8],[4,4],[0],[0],[],[],[],[],[],[]],capacities:[1,2,1,1,1,1,2,2,3,2],
            rules:[.normal,.normal,.normal,.normal,.normal,.normal,.sourceOnly,.normal,.normal,.normal],densityLayers:[[.medium],[.medium,.medium],[.medium],[.light],[],[],[],[],[],[]],behavior:.crossover,
            targets:[LabVialTarget(vial:8,layers:[.init(1,.heavy),.init(1,.heavy),.init(0,.light)]),LabVialTarget(vial:9,layers:[.init(2,.medium),.init(2,.medium)])],
            apparatus:[.mixer(id:0,inputs:[4,5],output:6),.modifier(id:1,chamber:7,direction:.heavier)])
        }
    }
    private static func mixingLevel(first:Int,second:Int,product:Int)->LabBoardState {
        LabBoardState(layers:[[first],[second],[],[],[],[]],capacities:[1,1,1,1,2,2],
            rules:[.normal,.normal,.normal,.normal,.sourceOnly,.normal],behavior:.mixing,
            targets:[LabVialTarget(vial:5,layers:[.init(product),.init(product)])],apparatus:[.mixer(inputs:[2,3],output:4)])
    }
    var authoredSteps:[LabAuthoredStep]? {
        switch self {
        case .splitPurple,.readyToBlend:return [.activate(0)]
        case .oneStepHeavier,.floatAgain:return [.pour(0,1),.activate(0),.pour(1,2)]
        case .roomForBoth:return [.pour(1,3),.activate(0)]
        case .secondChance:return [.activate(0),.activate(1)]
        case .keepEveryDrop:return [.activate(0),.activate(1),.activate(2),.pour(3,7),.pour(4,7)]
        case .heavyLanding:return [.pour(0,2),.pour(1,2)]
        case .threeDeep,.shadesOfBlue:return [.pour(0,3),.pour(1,3),.pour(2,3)]
        case .twinColumns:return [.pour(0,3),.pour(0,2),.pour(1,2),.pour(1,3)]
        case .againstThePour:return [.pour(0,3),.pour(0,2),.pour(4,3),.pour(4,2),.pour(1,3),.pour(1,2)]
        case .warmBlend,.coolBlend,.violetReaction:
            return [.pour(0,2),.pour(1,3),.activate(0),.pour(4,5)]
        case .colorWheel:
            return [.pour(0,3),.pour(1,4),.activate(0),.pour(5,6),
                    .pour(1,3),.pour(2,4),.activate(0),.pour(5,7),
                    .pour(0,3),.pour(2,4),.activate(0),.pour(5,8)]
        case .measuredBatch:
            return [.pour(0,3),.pour(1,4),.activate(0),.pour(5,6),
                    .pour(0,3),.pour(1,4),.activate(0),.pour(5,6),
                    .pour(2,3),.pour(1,4),.activate(0),.pour(5,7)]
        case .equalPartners:
            return [.pour(0,2),.activate(0),.pour(2,3),.pour(1,4),.activate(1),.pour(5,6)]
        case .weightedOrange:
            return [.pour(0,2),.pour(1,3),.activate(0),.pour(4,5),.activate(1),.pour(5,6)]
        case .layerCake:
            return [.pour(0,3),.pour(1,4),.activate(0),.pour(5,6),.activate(1),.pour(6,7),.pour(2,7)]
        case .twinProducts:
            return [.pour(0,3),.pour(1,4),.activate(0),.pour(5,6),.activate(1),.pour(6,8),
                    .pour(2,3),.pour(1,4),.activate(0),.pour(5,7),.activate(2),.pour(7,9)]
        case .fullSpectrum:
            return [.pour(2,4),.pour(1,5),.activate(0),.pour(6,9),
                    .pour(0,4),.pour(1,5),.activate(0),.pour(6,7),.activate(1),.pour(7,8),.pour(3,8)]
        default:return nil
        }
    }
    func authoredRoute(from initial:LabBoardState?=nil)->[LabBoardOperation]? {
        guard let steps=authoredSteps else {return nil}
        var state=initial ?? self.initial,result:[LabBoardOperation]=[]
        for step in steps {
            let operation:LabBoardOperation
            switch step {
            case .pour(let source,let destination):
                guard let move=state.move(from:source,to:destination) else {return nil};operation = .pour(move)
            case .activate(let id):operation = .activate(.init(apparatusID:id))
            }
            guard let next=state.applying(operation) else {return nil}
            result.append(operation);state=next
        }
        return state.solved ? result:nil
    }
}
/// A curated learning path over the existing boards. Progress is deliberately
/// shared with direct lab play; edges suggest learning order, never lock access.
nonisolated struct LabJourneyStop:Identifiable {
    let puzzle:LabBoardPuzzle
    let lesson:String
    let next:[LabBoardPuzzle]
    var id:LabBoardPuzzle {puzzle}
}
nonisolated enum LabJourney {
    static let stops:[LabJourneyStop]=[
        .init(puzzle:.firstSort,lesson:"Group matching colors and use an empty vial to make room.",next:[.crossCurrents]),
        .init(puzzle:.crossCurrents,lesson:"Plan a few pours ahead before choosing your next branch.",next:[.heavyLanding,.warmBlend,.firstReveal]),
        .init(puzzle:.heavyLanding,lesson:"Heavy liquid sinks through light liquid. Match the target’s layers.",next:[.threeDeep]),
        .init(puzzle:.threeDeep,lesson:"Arrange light, medium and heavy liquids in one target.",next:[.shadesOfBlue]),
        .init(puzzle:.shadesOfBlue,lesson:"The color is the same; use density symbols to tell the layers apart.",next:[.readyToBlend]),
        .init(puzzle:.warmBlend,lesson:"Make orange from one unit of red and one unit of yellow.",next:[.coolBlend]),
        .init(puzzle:.coolBlend,lesson:"Use the mixer to create green, then deliver it to the target.",next:[.violetReaction]),
        .init(puzzle:.violetReaction,lesson:"Complete the recipe family: blue and red make purple.",next:[.splitPurple]),
        .init(puzzle:.splitPurple,lesson:"Recover two ingredients from a mixture without losing any liquid.",next:[.roomForBoth]),
        .init(puzzle:.roomForBoth,lesson:"Clear a blocked output before separating; keep both recovered ingredients.",next:[.secondChance]),
        .init(puzzle:.secondChance,lesson:"Keep one recovered ingredient and remix the other into a new color.",next:[.readyToBlend]),
        .init(puzzle:.readyToBlend,lesson:"Two ready ingredients become two units of a new color. Activate the mixer.",next:[.oneStepHeavier]),
        .init(puzzle:.oneStepHeavier,lesson:"Move liquid through the chamber to make it one step heavier, then fill the target.",next:[.floatAgain]),
        .init(puzzle:.floatAgain,lesson:"Make medium liquid light. Its color and amount stay the same.",next:[.equalPartners]),
        .init(puzzle:.equalPartners,lesson:"Bring ingredients to the same density before mixing them.",next:[.weightedOrange]),
        .init(puzzle:.weightedOrange,lesson:"Mix the requested color, make it heavier, then fill the target.",next:[.layerCake]),
        .init(puzzle:.layerCake,lesson:"Combine a recipe with a target that requires a particular layer order.",next:[.twinProducts]),
        .init(puzzle:.twinProducts,lesson:"Plan two recipes and send each through the right density chamber.",next:[.fullSpectrum]),
        .init(puzzle:.fullSpectrum,lesson:"Combine color, quantity and density to complete both targets.",next:[]),
        .init(puzzle:.firstReveal,lesson:"Pour a known color to discover what is underneath.",next:[.peekAhead]),
        .init(puzzle:.peekAhead,lesson:"Choose which vial to investigate while keeping room to pour.",next:[.buriedClue]),
        .init(puzzle:.buriedClue,lesson:"Use what you have uncovered to plan the next few moves.",next:[.thirdColor]),
        .init(puzzle:.thirdColor,lesson:"Discover three colors in shallow vials before tackling deeper hidden layers.",next:[.hiddenGarden]),
        .init(puzzle:.hiddenGarden,lesson:"Put your discoveries together to sort three hidden colors.",next:[])
    ]
    static func stop(_ puzzle:LabBoardPuzzle)->LabJourneyStop? {stops.first {$0.puzzle==puzzle}}
    static func branch(_ discipline:LabDiscipline)->[LabJourneyStop] {stops.filter {$0.puzzle.discipline==discipline}}
}

/// Stable identifiers keep first-use teaching shared between Journey and direct labs.
/// The saved set uses strings so a future/unknown topic never invalidates a save.
nonisolated enum LabLearningTopic:String,CaseIterable,Identifiable {
    case discovery,density,mixing,recovery,heavier,lighter
    var id:String {rawValue}
    var title:String {
        switch self {
        case .discovery:"Discover hidden liquids"
        case .density:"Read the layers"
        case .mixing:"Use a mixer"
        case .recovery:"Recover the ingredients"
        case .heavier:"Make liquid heavier"
        case .lighter:"Make liquid lighter"
        }
    }
    var explanation:String {
        switch self {
        case .discovery:"Only exposed liquid is known. Pour a visible color to reveal the next layer. Once discovered, a layer stays known even after Undo or Play again."
        case .density:"Pale upward triangles mean light; no triangles mean medium; dark downward triangles mean heavy. Heavier liquid sinks below lighter liquid. Match each target’s color, amount and density."
        case .mixing:"Put one unit in each mixer input, at the same density. Activate Mix to make two units of a new color. The output must be empty, with room for both units."
        case .recovery:"Put exactly two units of one mixed color, at one density, in the separator input. Activate Separate to recover one unit of each ingredient. Both outputs need room."
        case .heavier:"Pour into the marked chamber, then activate Make heavier. Each activation changes light to medium or medium to heavy. Color and amount stay the same. Pour the result into its target or the next tool."
        case .lighter:"Pour into the marked chamber, then activate Make lighter. Each activation changes heavy to medium or medium to light. Color and amount stay the same. Pour the result into its target or the next tool."
        }
    }
    var reminder:String {
        switch self {
        case .discovery:"Hidden colors are a clue to uncover, not a new kind of liquid. Use empty space to investigate."
        case .density:"Target strips read left to right, from the bottom of the vial to the top. Select a target vial to learn what is missing."
        case .mixing:"Red + yellow = orange; yellow + blue = green; blue + red = purple."
        case .recovery:"Orange separates into red and yellow; green into yellow and blue; purple into blue and red. No liquid is lost."
        case .heavier,.lighter:"Use the machine’s information button to highlight its chamber and check whether it is ready."
        }
    }
    static func topic(for tool:LabApparatus)->Self {
        switch tool.kind {
        case .mixer:.mixing
        case .separator:.recovery
        case .densityModifier:tool.direction == .heavier ? .heavier:.lighter
        }
    }
    static func topics(for puzzle:LabBoardPuzzle)->[Self] {
        let state=puzzle.initial
        var result:[Self]=[]
        if state.behavior == .discovery {result.append(.discovery)}
        let densities=Set(state.densities+state.targets.flatMap {$0.layers.map(\.density)})
        if state.behavior.settlesByDensity && (densities.count>1 || state.apparatus.contains {$0.kind == .densityModifier}) {result.append(.density)}
        for tool in state.apparatus {
            let topic=topic(for:tool)
            if !result.contains(topic) {result.append(topic)}
        }
        return result
    }
}

struct LabComparisonSave:Codable {
    var seenLearningTopics:Set<String> = []
    var journeyMode:Bool = false
    var presentation:LabBoardPresentation = .fluid
    var pace:LabBoardPace = .relaxed
    var puzzle:LabBoardPuzzle = .firstSort
    var games:[String:LabBoardGame] = [:]
    var lastPuzzles:[String:String] = [:]
    /// Revised density starts must replace saved pre-settlement setups, without
    /// disturbing progress in the other three laboratories.
    var densitySetupVersion:Int = 1
    private enum CodingKeys:String,CodingKey {case presentation,pace,puzzle,games,lastPuzzles,densitySetupVersion,journeyMode,seenLearningTopics}
    init(presentation:LabBoardPresentation = .fluid,pace:LabBoardPace = .relaxed,puzzle:LabBoardPuzzle = .firstSort,games:[String:LabBoardGame] = [:],lastPuzzles:[String:String] = [:],densitySetupVersion:Int=1,journeyMode:Bool=false,seenLearningTopics:Set<String>=[]) {
        self.presentation=presentation;self.pace=pace;self.puzzle=puzzle;self.games=games;self.lastPuzzles=lastPuzzles;self.densitySetupVersion=densitySetupVersion;self.journeyMode=journeyMode;self.seenLearningTopics=seenLearningTopics
    }
    init(from decoder:Decoder)throws {
        let values=try decoder.container(keyedBy:CodingKeys.self)
        presentation=try values.decodeIfPresent(LabBoardPresentation.self,forKey:.presentation) ?? .fluid
        pace=try values.decodeIfPresent(LabBoardPace.self,forKey:.pace) ?? .relaxed
        puzzle=try values.decodeIfPresent(LabBoardPuzzle.self,forKey:.puzzle) ?? .firstSort
        games=try values.decodeIfPresent([String:LabBoardGame].self,forKey:.games) ?? [:]
        lastPuzzles=try values.decodeIfPresent([String:String].self,forKey:.lastPuzzles) ?? [:]
        densitySetupVersion=try values.decodeIfPresent(Int.self,forKey:.densitySetupVersion) ?? 0
        seenLearningTopics=try values.decodeIfPresent(Set<String>.self,forKey:.seenLearningTopics) ?? []
        journeyMode=try values.decodeIfPresent(Bool.self,forKey:.journeyMode) ?? false
    }
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
