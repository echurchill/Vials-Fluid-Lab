import Foundation

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
}

nonisolated struct LabBoardState: Sendable, Equatable, Codable {
    let colors: [Int]
    var stacks: [[Int]] // bottom to top, containing stable unit IDs
    let capacities: [Int]
    let rules: [LabVialRule]

    init(layers: [[Int]], capacity: Int = 4) {
        self.init(layers:layers,capacities:Array(repeating:capacity,count:layers.count))
    }
    init(layers:[[Int]],capacities:[Int],rules:[LabVialRule]?=nil) {
        precondition(capacities.count==layers.count && zip(layers,capacities).allSatisfy { $0.count <= $1 && $1 > 0 })
        var colors:[Int]=[], stacks:[[Int]]=[]
        for layer in layers {
            let start=colors.count
            colors += layer
            stacks.append(Array(start..<colors.count))
        }
        self.colors=colors;self.stacks=stacks;self.capacities=capacities
        self.rules=rules ?? Array(repeating:.normal,count:layers.count)
        precondition(self.rules.count==layers.count)
    }
    private enum CodingKeys:String,CodingKey { case colors,stacks,capacity,capacities,rules }
    init(from decoder:Decoder) throws {
        let values=try decoder.container(keyedBy:CodingKeys.self)
        colors=try values.decode([Int].self,forKey:.colors)
        stacks=try values.decode([[Int]].self,forKey:.stacks)
        if let decoded=try values.decodeIfPresent([Int].self,forKey:.capacities) { capacities=decoded }
        else {
            let legacy=try values.decodeIfPresent(Int.self,forKey:.capacity) ?? 4
            capacities=Array(repeating:legacy,count:stacks.count)
        }
        rules=try values.decodeIfPresent([LabVialRule].self,forKey:.rules) ?? Array(repeating:.normal,count:stacks.count)
        guard capacities.count==stacks.count,rules.count==stacks.count,
              zip(stacks,capacities).allSatisfy({$0.count <= $1 && $1 > 0}) else {
            throw DecodingError.dataCorrupted(.init(codingPath:decoder.codingPath,debugDescription:"Invalid Fluid Lab vial metadata"))
        }
    }
    func encode(to encoder:Encoder) throws {
        var values=encoder.container(keyedBy:CodingKeys.self)
        try values.encode(colors,forKey:.colors);try values.encode(stacks,forKey:.stacks)
        try values.encode(capacities,forKey:.capacities);try values.encode(rules,forKey:.rules)
    }
    nonisolated static let firstSort = LabBoardState(layers:[[0,1,1],[1,0,0],[0,1],[]])
    var maximumCapacity:Int { capacities.max() ?? 0 }
    func capacity(_ index:Int)->Int { capacities[index] }
    func canPourOut(_ index:Int)->Bool { rules[index] == .normal }
    func isComplete(_ index:Int) -> Bool {
        guard stacks.indices.contains(index) else { return false }
        let stack=stacks[index]
        return stack.count==capacities[index] && Set(stack.map { colors[$0] }).count==1
    }
    var solved: Bool {
        stacks.indices.allSatisfy { stacks[$0].isEmpty || isComplete($0) }
    }
    func move(from source:Int,to destination:Int) -> LabBoardMove? {
        guard stacks.indices.contains(source), stacks.indices.contains(destination), source != destination,
              canPourOut(source),let top=stacks[source].last, stacks[destination].count < capacities[destination] else { return nil }
        let color=colors[top]
        guard stacks[destination].last.map({ colors[$0] == color }) ?? true else { return nil }
        let run=stacks[source].reversed().prefix { colors[$0] == color }.count
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
              canPourOut(move.source),stacks[move.destination].count+move.amount<=capacities[move.destination],
              stacks[move.destination].last.map({colors[$0]==move.color}) ?? true else { return nil }
        var next=self
        next.stacks[move.source].removeLast(move.amount)
        next.stacks[move.destination] += move.parcels
        return next
    }
    var colorKey: String { stacks.map { $0.map { String(colors[$0]) }.joined(separator:",") }.joined(separator:"|") }
    // Only vials with the same capacity and rule are interchangeable.
    private var searchKey:String {
        stacks.indices.map { index in
            "\(capacities[index]):\(rules[index].rawValue):"+stacks[index].map { String(colors[$0]) }.joined(separator:",")
        }.sorted().joined(separator:"|")
    }
    private func searchMoves()->[LabBoardMove] {
        var totals:[Int:Int]=[:]
        for id in stacks.flatMap({$0}) {totals[colors[id],default:0]+=1}
        var moves:[LabBoardMove]=[]
        for source in stacks.indices where rules[source] == .normal {
            guard let top=stacks[source].last else {continue}
            let color=colors[top]
            let finished=stacks[source].count==capacities[source] && Set(stacks[source].map {colors[$0]}).count==1
            let ownsColor=totals[color,default:0]==stacks[source].count
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
