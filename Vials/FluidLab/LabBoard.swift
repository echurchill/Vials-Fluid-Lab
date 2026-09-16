import Foundation

/// Unit IDs never change; color and exact volume survive simulation and undo.
nonisolated struct LabBoardMove: Sendable, Equatable, Codable {
    let source: Int
    let destination: Int
    let parcels: [Int]
    let color: Int
    var amount: Int { parcels.count }
}

nonisolated struct LabBoardState: Sendable, Equatable, Codable {
    let colors: [Int]
    var stacks: [[Int]] // bottom to top, containing stable unit IDs
    let capacity: Int

    init(layers: [[Int]], capacity: Int = 4) {
        self.capacity=capacity
        var colors:[Int]=[], stacks:[[Int]]=[]
        for layer in layers {
            let start=colors.count
            colors += layer
            stacks.append(Array(start..<colors.count))
        }
        self.colors=colors; self.stacks=stacks
    }
    nonisolated static let firstSort = LabBoardState(layers:[[0,1,1],[1,0,0],[0,1],[]])
    func isComplete(_ index:Int) -> Bool {
        guard stacks.indices.contains(index) else { return false }
        let stack=stacks[index]
        return stack.count==capacity && Set(stack.map { colors[$0] }).count==1
    }
    var solved: Bool {
        stacks.indices.allSatisfy { stacks[$0].isEmpty || isComplete($0) }
    }
    func move(from source:Int,to destination:Int) -> LabBoardMove? {
        guard stacks.indices.contains(source), stacks.indices.contains(destination), source != destination,
              let top=stacks[source].last, stacks[destination].count < capacity else { return nil }
        let color=colors[top]
        guard stacks[destination].last.map({ colors[$0] == color }) ?? true else { return nil }
        let run=stacks[source].reversed().prefix { colors[$0] == color }.count
        let amount=min(run,capacity-stacks[destination].count)
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
              stacks[move.destination].count+move.amount<=capacity,
              stacks[move.destination].last.map({colors[$0]==move.color}) ?? true else { return nil }
        var next=self
        next.stacks[move.source].removeLast(move.amount)
        next.stacks[move.destination] += move.parcels
        return next
    }
    var colorKey: String { stacks.map { $0.map { String(colors[$0]) }.joined(separator:",") }.joined(separator:"|") }
    // Vial permutations have the same reachability; retain the actual route and IDs.
    private var searchKey:String { stacks.map { $0.map { String(colors[$0]) }.joined(separator:",") }.sorted().joined(separator:"|") }
    func solution(limit:Int=20_000) -> [LabBoardMove]? {
        if solved { return [] }
        var queue:[(LabBoardState,[LabBoardMove])]=[(self,[])], head=0
        var seen:Set<String>=[searchKey]
        while head < queue.count && head < limit {
            let (state,path)=queue[head];head += 1
            for a in state.stacks.indices { for b in state.stacks.indices {
                if state.stacks[b].isEmpty, Set(state.stacks[a].map { state.colors[$0] }).count == 1 { continue }
                guard let move=state.move(from:a,to:b), let next=state.applying(move), seen.insert(next.searchKey).inserted else { continue }
                let route=path+[move]
                if next.solved { return route }
                queue.append((next,route))
            }}
        }
        return nil
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
    mutating func startReady(limit:Int=2)->[LabPourReservation] {
        var count=active.count,result:[LabPourReservation]=[]
        for i in items.indices where !items[i].started {
            guard count<limit else { break }
            let move=items[i].move
            let running=active
            guard !running.contains(where: { $0.move.source==move.source || $0.move.destination==move.source || $0.move.source==move.destination }) else { continue }
            let preferred:Float=move.destination>move.source ? 1:-1
            let used=Set(running.filter { $0.move.destination==move.destination }.map(\.approach))
            guard used.count<2 else { continue }
            items[i].approach=used.contains(preferred) ? -preferred:preferred
            let occupiedDepth=Set(running.map(\.depthSide))
            items[i].depthSide=occupiedDepth.contains(1) ? -1:1
            items[i].started=true;result.append(items[i]);count+=1
        }
        return result
    }
    mutating func unstart(_ ids:Set<Int>) { for i in items.indices where ids.contains(items[i].id) { items[i].started=false } }
    mutating func finish(_ id:Int) { items.removeAll { $0.id==id } }
    mutating func cancelAll() { items=[] }
}
