import Foundation

nonisolated enum LabDensity:String,CaseIterable,Sendable,Codable {
    case light,medium,heavy
    var title:String { rawValue.capitalized }
    var shortTitle:String { switch self { case .light:"L";case .medium:"M";case .heavy:"H" } }
    var order:Int { switch self { case .heavy:0;case .medium:1;case .light:2 } }
    /// Encodes pigment plus density for rendering. Hue uses pigment modulo 12;
    /// the higher banks select light/heavy motifs rather than brightness.
    var visualBank:Int { switch self { case .medium:0;case .light:1;case .heavy:2 } }
}

nonisolated enum LabBehavior:String,Sendable,Codable {
    case sorting,density,mixing,crossover
    var settlesByDensity:Bool { self == .density || self == .crossover }
    var unrestrictedDestinations:Bool { settlesByDensity }
}

nonisolated struct LabMaterialSpec:Sendable,Equatable,Hashable,Codable {
    let pigment:Int
    let density:LabDensity
    init(_ pigment:Int,_ density:LabDensity = .medium) { self.pigment=pigment;self.density=density }
}

/// Explains the first useful difference without changing exact target matching.
nonisolated enum LabTargetAssessment:Equatable,Sendable {
    case matched,needsUnits(Int),extraUnits(Int),wrongColors,wrongOrder,tooHeavy,tooLight,mixedDensity
    var shortLabel:String {
        switch self {
        case .matched:"Matched"
        case .needsUnits(let n):"Needs \(n)"
        case .extraUnits(let n):"\(n) extra"
        case .wrongColors:"Check color"
        case .wrongOrder:"Check layers"
        case .tooHeavy:"Too heavy"
        case .tooLight:"Too light"
        case .mixedDensity:"Check density"
        }
    }
    var explanation:String {
        switch self {
        case .matched:"Color, amount and layers match."
        case .needsUnits(let n):"Needs \(n) more \(n == 1 ? "unit":"units"). Then check color and density."
        case .extraUnits(let n):"Contains \(n) extra \(n == 1 ? "unit":"units")."
        case .wrongColors:"Correct amount; the colors do not match the target."
        case .wrongOrder:"Correct colors and amount; match the target's layer order and densities."
        case .tooHeavy:"Correct color and amount; the liquid is too heavy."
        case .tooLight:"Correct color and amount; the liquid is too light."
        case .mixedDensity:"Correct colors and amount; some layers need a different density."
        }
    }
}

nonisolated struct LabVialTarget:Sendable,Equatable,Codable {
    let vial:Int
    let layers:[LabMaterialSpec] // bottom to top
}

nonisolated enum LabModifierDirection:String,Sendable,Codable {
    case lighter,heavier
}

nonisolated enum LabApparatusKind:String,Sendable,Codable {
    case mixer,densityModifier
}

nonisolated struct LabApparatus:Sendable,Equatable,Codable,Identifiable {
    let id:Int
    let kind:LabApparatusKind
    let inputs:[Int]
    let output:Int?
    let direction:LabModifierDirection?
    static func mixer(id:Int=0,inputs:[Int],output:Int)->Self {
        Self(id:id,kind:.mixer,inputs:inputs,output:output,direction:nil)
    }
    static func modifier(id:Int=0,chamber:Int,direction:LabModifierDirection)->Self {
        Self(id:id,kind:.densityModifier,inputs:[chamber],output:nil,direction:direction)
    }
    var title:String {
        switch kind {
        case .mixer:return "Mix"
        case .densityModifier:return direction == .heavier ? "Make heavier":"Make lighter"
        }
    }
}

nonisolated struct LabApparatusActivation:Sendable,Equatable,Codable,Hashable {
    let apparatusID:Int
}

nonisolated enum LabBoardOperation:Sendable,Equatable,Codable {
    case pour(LabBoardMove)
    case activate(LabApparatusActivation)
}

/// Unit IDs never change; color and exact volume survive simulation and undo.
nonisolated struct LabBoardMove: Sendable, Equatable, Codable {
    let source: Int
    let destination: Int
    let parcels: [Int]
    let color: Int
    var amount: Int { parcels.count }
}

nonisolated enum LabVialRule:String,Sendable,Codable {
    case normal
    case receiveOnly
    case sourceOnly
}

nonisolated struct LabBoardState: Sendable, Equatable, Codable {
    var colors: [Int]
    var densities:[LabDensity]
    var stacks: [[Int]] // bottom to top, containing stable unit IDs
    let capacities: [Int]
    let rules: [LabVialRule]
    let behavior:LabBehavior
    let targets:[LabVialTarget]
    let apparatus:[LabApparatus]

    init(layers: [[Int]], capacity: Int = 4) {
        self.init(layers:layers,capacities:Array(repeating:capacity,count:layers.count))
    }
    init(layers:[[Int]],capacities:[Int],rules:[LabVialRule]?=nil,densityLayers:[[LabDensity]]?=nil,
         behavior:LabBehavior = .sorting,targets:[LabVialTarget]=[],apparatus:[LabApparatus]=[]) {
        precondition(capacities.count==layers.count && zip(layers,capacities).allSatisfy { $0.count <= $1 && $1 > 0 })
        if let densityLayers { precondition(densityLayers.count==layers.count && zip(layers,densityLayers).allSatisfy {$0.count==$1.count}) }
        var colors:[Int]=[],densities:[LabDensity]=[],stacks:[[Int]]=[]
        for (index,layer) in layers.enumerated() {
            let start=colors.count
            colors += layer
            densities += densityLayers?[index] ?? Array(repeating:.medium,count:layer.count)
            stacks.append(Array(start..<colors.count))
        }
        self.colors=colors;self.densities=densities;self.stacks=stacks;self.capacities=capacities
        self.rules=rules ?? Array(repeating:.normal,count:layers.count)
        self.behavior=behavior;self.targets=targets;self.apparatus=apparatus
        precondition(self.rules.count==layers.count)
        precondition(targets.allSatisfy { stacks.indices.contains($0.vial) && $0.layers.count<=capacities[$0.vial] })
        precondition(apparatus.flatMap(\.inputs).allSatisfy(stacks.indices.contains))
        precondition(apparatus.compactMap(\.output).allSatisfy(stacks.indices.contains))
    }
    private enum CodingKeys:String,CodingKey { case colors,densities,stacks,capacity,capacities,rules,behavior,targets,apparatus }
    init(from decoder:Decoder) throws {
        let values=try decoder.container(keyedBy:CodingKeys.self)
        colors=try values.decode([Int].self,forKey:.colors)
        densities=try values.decodeIfPresent([LabDensity].self,forKey:.densities) ?? Array(repeating:.medium,count:colors.count)
        stacks=try values.decode([[Int]].self,forKey:.stacks)
        if let decoded=try values.decodeIfPresent([Int].self,forKey:.capacities) { capacities=decoded }
        else {
            let legacy=try values.decodeIfPresent(Int.self,forKey:.capacity) ?? 4
            capacities=Array(repeating:legacy,count:stacks.count)
        }
        rules=try values.decodeIfPresent([LabVialRule].self,forKey:.rules) ?? Array(repeating:.normal,count:stacks.count)
        behavior=try values.decodeIfPresent(LabBehavior.self,forKey:.behavior) ?? .sorting
        targets=try values.decodeIfPresent([LabVialTarget].self,forKey:.targets) ?? []
        apparatus=try values.decodeIfPresent([LabApparatus].self,forKey:.apparatus) ?? []
        guard capacities.count==stacks.count,rules.count==stacks.count,densities.count==colors.count,
              zip(stacks,capacities).allSatisfy({$0.count <= $1 && $1 > 0}) else {
            throw DecodingError.dataCorrupted(.init(codingPath:decoder.codingPath,debugDescription:"Invalid Fluid Lab vial metadata"))
        }
    }
    func encode(to encoder:Encoder) throws {
        var values=encoder.container(keyedBy:CodingKeys.self)
        try values.encode(colors,forKey:.colors);try values.encode(densities,forKey:.densities);try values.encode(stacks,forKey:.stacks)
        try values.encode(capacities,forKey:.capacities);try values.encode(rules,forKey:.rules)
        try values.encode(behavior,forKey:.behavior);try values.encode(targets,forKey:.targets);try values.encode(apparatus,forKey:.apparatus)
    }
    nonisolated static let firstSort = LabBoardState(layers:[[0,1,1],[1,0,0],[0,1],[]])
    var maximumCapacity:Int { capacities.max() ?? 0 }
    func capacity(_ index:Int)->Int { capacities[index] }
    func canPourOut(_ index:Int)->Bool { rules[index] != .receiveOnly }
    func canPourIn(_ index:Int)->Bool { rules[index] != .sourceOnly }
    func material(_ parcel:Int)->LabMaterialSpec { LabMaterialSpec(colors[parcel],densities[parcel]) }
    func visualDye(_ parcel:Int)->Int { colors[parcel]+densities[parcel].visualBank*12 }
    func sameMaterial(_ a:Int,_ b:Int)->Bool { colors[a]==colors[b] && densities[a]==densities[b] }
    func target(_ index:Int)->LabVialTarget? { targets.first {$0.vial==index} }
    func matchesTarget(_ target:LabVialTarget)->Bool {
        stacks.indices.contains(target.vial) && stacks[target.vial].map(material)==target.layers
    }
    func targetAssessment(_ index:Int)->LabTargetAssessment? {
        guard stacks.indices.contains(index),let target=target(index) else {return nil}
        let actual=stacks[index].map(material),wanted=target.layers
        if actual==wanted {return .matched}
        if actual.count<wanted.count {return .needsUnits(wanted.count-actual.count)}
        if actual.count>wanted.count {return .extraUnits(actual.count-wanted.count)}
        if actual.map(\.pigment).sorted() != wanted.map(\.pigment).sorted() {return .wrongColors}
        if actual.map(\.pigment) != wanted.map(\.pigment) {return .wrongOrder}
        let differences=zip(actual,wanted).map {$0.density.order-$1.density.order}.filter {$0 != 0}
        if differences.allSatisfy({$0<0}) {return .tooHeavy}
        if differences.allSatisfy({$0>0}) {return .tooLight}
        return .mixedDensity
    }
    func isComplete(_ index:Int) -> Bool {
        guard stacks.indices.contains(index) else { return false }
        if !targets.isEmpty {return target(index).map(matchesTarget) ?? false}
        let stack=stacks[index]
        return stack.count==capacities[index] && Set(stack.map { colors[$0] }).count==1
    }
    var solved: Bool {
        if !targets.isEmpty { return targets.allSatisfy(matchesTarget) }
        return stacks.indices.allSatisfy { stacks[$0].isEmpty || isComplete($0) }
    }
    private var apparatusInputs:Set<Int> { Set(apparatus.flatMap(\.inputs)) }
    func move(from source:Int,to destination:Int) -> LabBoardMove? {
        guard stacks.indices.contains(source), stacks.indices.contains(destination), source != destination,
              canPourOut(source),canPourIn(destination),let top=stacks[source].last, stacks[destination].count < capacities[destination] else { return nil }
        let color=colors[top]
        let acceptsDifferent=behavior.unrestrictedDestinations || apparatusInputs.contains(destination)
        guard acceptsDifferent || (stacks[destination].last.map({ sameMaterial($0,top) }) ?? true) else { return nil }
        let run=stacks[source].reversed().prefix { sameMaterial($0,top) }.count
        let amount=min(run,capacities[destination]-stacks[destination].count)
        return LabBoardMove(source:source,destination:destination,parcels:Array(stacks[source].suffix(amount)),color:color)
    }
    func applying(_ move:LabBoardMove) -> LabBoardState? {
        guard self.move(from:move.source,to:move.destination) == move else { return nil }
        return applyingReserved(move)
    }
    /// Accepted amounts remain exact when a different incoming pour finishes first.
    func applyingReserved(_ move:LabBoardMove) -> LabBoardState? {
        guard stacks.indices.contains(move.source),stacks.indices.contains(move.destination),move.source != move.destination,
              move.amount>0,move.amount<=stacks[move.source].count,
              Array(stacks[move.source].suffix(move.amount))==move.parcels,
              move.parcels.allSatisfy({ colors[$0]==move.color }),
              canPourOut(move.source),canPourIn(move.destination),stacks[move.destination].count+move.amount<=capacities[move.destination] else { return nil }
        let top=move.parcels.last!,acceptsDifferent=behavior.unrestrictedDestinations || apparatusInputs.contains(move.destination)
        guard acceptsDifferent || (stacks[move.destination].last.map({sameMaterial($0,top)}) ?? true) else {return nil}
        var next=self
        next.stacks[move.source].removeLast(move.amount)
        next.stacks[move.destination] += move.parcels
        if behavior.settlesByDensity { next.settle(move.destination) }
        return next
    }
    /// Stable density insertion shared by the three presentations. Equal density
    /// stays below the new arrival, even when the pigments differ.
    func densityInsertionIndex(for move:LabBoardMove)->Int {
        let order=densities[move.parcels[0]].order
        return stacks[move.destination].firstIndex { densities[$0].order>order } ?? stacks[move.destination].count
    }
    func densityReceiverLayers(for move:LabBoardMove,joinedUnits:Float)->[(parcel:Int,units:Float)] {
        var layers=stacks[move.destination].map { (parcel:$0,units:Float(1)) }
        let fraction=min(Float(move.amount),max(0,joinedUnits))/Float(move.amount)
        layers.insert(contentsOf:move.parcels.map { (parcel:$0,units:fraction) },at:densityInsertionIndex(for:move))
        return layers
    }
    func densityReceiverBands(for move:LabBoardMove,joinedUnits:Float)->[Int:SIMD2<Float>] {
        let layers=densityReceiverLayers(for:move,joinedUnits:joinedUnits),incoming=Set(move.parcels)
        var result:[Int:SIMD2<Float>]=[:],units:Float=0,index=0
        while index<layers.count {
            let start=units,id=layers[index].parcel
            var end=index
            repeat { units+=layers[end].units;end+=1 }
            while end<layers.count && sameMaterial(id,layers[end].parcel) && incoming.contains(id)==incoming.contains(layers[end].parcel)
            for n in index..<end { result[layers[n].parcel]=SIMD2(start,units) }
            index=end
        }
        return result
    }
    private mutating func settle(_ index:Int) {
        stacks[index]=stacks[index].enumerated().sorted {
            let left=densities[$0.element].order,right=densities[$1.element].order
            return left==right ? $0.offset<$1.offset:left<right
        }.map(\.element)
    }
    var colorKey: String { stacks.map { $0.map { "\(colors[$0]).\(densities[$0].rawValue)" }.joined(separator:",") }.joined(separator:"|") }
    // Only vials with the same capacity and rule are interchangeable.
    private var searchKey:String {
        let components=stacks.indices.map { index in
            "\(capacities[index]):\(rules[index].rawValue):"+stacks[index].map { "\(colors[$0]).\(densities[$0].rawValue)" }.joined(separator:",")
        }
        // Targets and apparatus attach meaning to concrete vial positions.
        // Only the legacy free-standing sorting vials are interchangeable.
        return (targets.isEmpty && apparatus.isEmpty ? components.sorted():components).joined(separator:"|")
    }
    private func searchMoves()->[LabBoardMove] {
        var totals:[Int:Int]=[:]
        for id in stacks.flatMap({$0}) {totals[colors[id],default:0]+=1}
        var moves:[LabBoardMove]=[]
        for source in stacks.indices where canPourOut(source) {
            guard let top=stacks[source].last else {continue}
            let color=colors[top]
            let finished=targets.isEmpty && stacks[source].count==capacities[source] && Set(stacks[source].map {colors[$0]}).count==1
            let ownsColor=targets.isEmpty && totals[color,default:0]==stacks[source].count
            for destination in stacks.indices where destination != source {
                if stacks[destination].isEmpty && finished && ownsColor {continue}
                if let move=move(from:source,to:destination) {moves.append(move)}
            }
        }
        return moves.sorted {
            if stacks[$0.destination].count != stacks[$1.destination].count {
                return stacks[$0.destination].count > stacks[$1.destination].count
            }
            return $0.amount > $1.amount
        }
    }

    func canActivate(_ activation:LabApparatusActivation)->Bool {
        guard let tool=apparatus.first(where:{$0.id==activation.apparatusID}) else {return false}
        switch tool.kind {
        case .mixer:
            guard tool.inputs.count==2,let output=tool.output,
                  stacks[tool.inputs[0]].count==1,stacks[tool.inputs[1]].count==1,stacks[output].isEmpty,capacities[output]>=2 else {return false}
            let a=stacks[tool.inputs[0]][0],b=stacks[tool.inputs[1]][0]
            return densities[a]==densities[b] && Self.mixedPigment(colors[a],colors[b]) != nil
        case .densityModifier:
            guard let chamber=tool.inputs.first,let first=stacks[chamber].first,!stacks[chamber].isEmpty,
                  stacks[chamber].allSatisfy({sameMaterial($0,first)}),let direction=tool.direction else {return false}
            return direction == .heavier ? densities[first] != .heavy:densities[first] != .light
        }
    }
    func applying(_ activation:LabApparatusActivation)->LabBoardState? {
        guard canActivate(activation),let tool=apparatus.first(where:{$0.id==activation.apparatusID}) else {return nil}
        var next=self
        switch tool.kind {
        case .mixer:
            let a=next.stacks[tool.inputs[0]].removeLast(),b=next.stacks[tool.inputs[1]].removeLast(),output=tool.output!
            let pigment=Self.mixedPigment(next.colors[a],next.colors[b])!
            next.colors[a]=pigment;next.colors[b]=pigment
            next.stacks[output]=[a,b]
        case .densityModifier:
            let chamber=tool.inputs[0],direction=tool.direction!
            for parcel in next.stacks[chamber] {
                switch (direction,next.densities[parcel]) {
                case (.heavier,.light):next.densities[parcel] = .medium
                case (.heavier,.medium):next.densities[parcel] = .heavy
                case (.lighter,.heavy):next.densities[parcel] = .medium
                case (.lighter,.medium):next.densities[parcel] = .light
                default:break
                }
            }
            if next.behavior.settlesByDensity {next.settle(chamber)}
        }
        return next
    }
    static func mixedPigment(_ a:Int,_ b:Int)->Int? {
        switch Set([a,b]) {
        case Set([8,4]):return 1 // red + yellow = orange
        case Set([4,0]):return 2 // yellow + blue = green
        case Set([0,8]):return 6 // blue + red = violet
        default:return nil
        }
    }
    func applying(_ operation:LabBoardOperation)->LabBoardState? {
        switch operation {case .pour(let move):return applying(move);case .activate(let activation):return applying(activation)}
    }
    private func searchOperations()->[LabBoardOperation] {
        apparatus.map {LabBoardOperation.activate(.init(apparatusID:$0.id))}.filter {applying($0) != nil}+searchMoves().map(LabBoardOperation.pour)
    }
    func operationSolution(limit:Int=800_000,depthLimit:Int=48)->[LabBoardOperation]? {
        if solved {return []}
        var queue:[(LabBoardState,[LabBoardOperation])]=[(self,[])],visited:Set<String>=[searchKey],cursor=0
        while cursor<queue.count && cursor<limit {
            let (state,path)=queue[cursor];cursor+=1
            guard path.count<depthLimit else {continue}
            for operation in state.searchOperations() {
                guard let next=state.applying(operation) else {continue}
                let route=path+[operation]
                if next.solved {return route}
                let key=next.searchKey
                if visited.insert(key).inserted {queue.append((next,route))}
            }
        }
        return nil
    }
    func solution(limit:Int=600_000,depthLimit:Int?=nil) -> [LabBoardMove]? {
        if solved { return [] }
        let maximumDepth=depthLimit ?? min(80,16+colors.count)
        var visited=[searchKey:maximumDepth],nodes=0
        func search(_ state:LabBoardState,_ depth:Int,_ path:[LabBoardMove])->[LabBoardMove]? {
            if state.solved {return path}
            guard depth>0,nodes<limit else {return nil}
            nodes+=1
            for move in state.searchMoves() {
                guard let next=state.applying(move) else {continue}
                let remaining=depth-1,key=next.searchKey
                if let previous=visited[key],previous>=remaining {continue}
                visited[key]=remaining
                if let route=search(next,remaining,path+[move]) {return route}
            }
            return nil
        }
        return search(self,maximumDepth,[])
    }
}

nonisolated struct LabBoardGame: Sendable, Codable {
    private(set) var state:LabBoardState
    private(set) var pending:LabBoardMove?
    private(set) var history:[LabBoardState]=[]
    var moveCount:Int { history.count }
    init(state:LabBoardState = .firstSort) { self.state=state }
    mutating func begin(from:Int,to:Int,reserved:Bool=false) -> LabBoardMove? {
        guard pending == nil, (reserved || !state.solved), let move=state.move(from:from,to:to) else { return nil }
        pending=move;return move
    }
    mutating func commit(_ move:LabBoardMove) -> Bool {
        guard pending == move,let next=state.applying(move) else { return false }
        history.append(state);state=next;pending=nil;return true
    }
    /// A previously reserved independent move may finish while another is active.
    mutating func commitReserved(_ move:LabBoardMove)->Bool {
        guard pending == nil,let next=state.applyingReserved(move) else { return false }
        history.append(state);state=next;return true
    }
    mutating func activate(_ activation:LabApparatusActivation)->Bool {
        guard pending==nil,let next=state.applying(activation) else {return false}
        history.append(state);state=next;return true
    }
    mutating func cancel() { pending=nil }
    mutating func undo() -> Bool {
        guard pending == nil,let previous=history.popLast() else { return false }
        state=previous;return true
    }
}

nonisolated struct LabPourReservation:Identifiable,Sendable {
    let id:Int
    let move:LabBoardMove
    var started=false
    var approach:Float=0 // Stable tilt direction / receiver approach slot.
    var depthSide:Float=0 // Stable 3D travel lane; never reassigned mid-pour.
    var vessels:Set<Int> { [move.source,move.destination] }
}
/// Reservations are made against the projected board, never against empty space
/// that another accepted move already owns. Sources are exclusive; receivers may be shared.
nonisolated struct LabPourQueue:Sendable {
    private(set) var items:[LabPourReservation]=[]
    private var nextID=0
    var busy:Bool { !items.isEmpty }
    var active:[LabPourReservation] { items.filter(\.started) }
    var lockedSources:Set<Int> { Set(items.flatMap { [$0.move.source,$0.move.destination] }) }
    var movingSources:Set<Int> { Set(items.map { $0.move.source }) }
    func projected(_ state:LabBoardState)->LabBoardState {
        items.reduce(state) { current,item in current.applyingReserved(item.move) ?? current }
    }
    func move(from:Int,to:Int,state:LabBoardState)->LabBoardMove? {
        guard !lockedSources.contains(from),!movingSources.contains(to) else { return nil }
        return projected(state).move(from:from,to:to)
    }
    mutating func reserve(_ move:LabBoardMove,state:LabBoardState)->Bool {
        guard self.move(from:move.source,to:move.destination,state:state)==move else { return false }
        items.append(LabPourReservation(id:nextID,move:move));nextID+=1;return true
    }
    mutating func startReady()->[LabPourReservation] {
        var result:[LabPourReservation]=[]
        for i in items.indices where !items[i].started {
            let move=items[i].move
            let running=active
            guard !running.contains(where: { $0.move.source==move.source || $0.move.destination==move.source || $0.move.source==move.destination }) else { continue }
            let preferred:Float=move.destination>move.source ? 1:-1
            let used=Set(running.filter { $0.move.destination==move.destination }.map(\.approach))
            guard used.count<2 else { continue }
            items[i].approach=used.contains(preferred) ? -preferred:preferred
            let occupiedDepth=Set(running.map(\.depthSide))
            items[i].depthSide=occupiedDepth.contains(1) ? -1:1
            items[i].started=true;result.append(items[i])
        }
        return result
    }
    mutating func unstart(_ ids:Set<Int>) { for i in items.indices where ids.contains(items[i].id) { items[i].started=false } }
    mutating func finish(_ id:Int) { items.removeAll { $0.id==id } }
    mutating func cancelAll() { items=[] }
}
