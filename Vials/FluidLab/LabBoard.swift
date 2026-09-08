import Foundation

/// Unit IDs never change; color and exact volume survive simulation and undo.
struct LabBoardMove: Equatable {
    let source: Int
    let destination: Int
    let parcels: [Int]
    let color: Int
    var amount: Int { parcels.count }
}

struct LabBoardState: Equatable {
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
    var solved: Bool {
        stacks.allSatisfy { $0.isEmpty || ($0.count == capacity && Set($0.map { colors[$0] }).count == 1) }
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
        var next=self
        next.stacks[move.source].removeLast(move.amount)
        next.stacks[move.destination] += move.parcels
        return next
    }
    var colorKey: String { stacks.map { $0.map { String(colors[$0]) }.joined(separator:",") }.joined(separator:"|") }
    func solution(limit:Int=20_000) -> [LabBoardMove]? {
        if solved { return [] }
        var queue:[(LabBoardState,[LabBoardMove])]=[(self,[])], head=0
        var seen:Set<String>=[colorKey]
        while head < queue.count && head < limit {
            let (state,path)=queue[head];head += 1
            for a in state.stacks.indices { for b in state.stacks.indices {
                guard let move=state.move(from:a,to:b), let next=state.applying(move), seen.insert(next.colorKey).inserted else { continue }
                let route=path+[move]
                if next.solved { return route }
                queue.append((next,route))
            }}
        }
        return nil
    }
}

struct LabBoardGame {
    private(set) var state:LabBoardState
    private(set) var pending:LabBoardMove?
    private(set) var history:[LabBoardState]=[]
    var moveCount:Int { history.count }
    init(state:LabBoardState = .firstSort) { self.state=state }
    mutating func begin(from:Int,to:Int) -> LabBoardMove? {
        guard pending == nil, !state.solved, let move=state.move(from:from,to:to) else { return nil }
        pending=move;return move
    }
    mutating func commit(_ move:LabBoardMove) -> Bool {
        guard pending == move,let next=state.applying(move) else { return false }
        history.append(state);state=next;pending=nil;return true
    }
    mutating func cancel() { pending=nil }
    mutating func undo() -> Bool {
        guard pending == nil,let previous=history.popLast() else { return false }
        state=previous;return true
    }
}
