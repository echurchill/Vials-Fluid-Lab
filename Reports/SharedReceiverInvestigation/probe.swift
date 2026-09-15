import Foundation
@main struct Probe {
 static func main() {
  let state=LabBoardState(layers:[[0,0,0],[0,0,0],[],[]])
  var queue=LabPourQueue()
  let a=queue.move(from:0,to:2,state:state)!;precondition(queue.reserve(a,state:state))
  let b=queue.move(from:1,to:2,state:state)!;precondition(queue.reserve(b,state:state))
  print("3+3 into empty: reserved amounts \(a.amount)+\(b.amount)")
  print("Current dispatch starts \(queue.startReady().count) pour")
  print("Second can begin against current committed board: \(state.move(from:1,to:2)==b)")
  print("Second can commit first with current applying: \(state.applying(b) != nil)")
  print("Acceptance order succeeds: \(state.applying(a)?.applying(b)?.stacks[2].count == 4)")
  let balanced=LabBoardState(layers:[[0,0],[0,0],[],[]])
  let c=balanced.move(from:0,to:2)!,d=balanced.move(from:1,to:2)!
  print("2+2 reverse completion succeeds: \(balanced.applying(d)?.applying(c)?.stacks[2].count == 4)")
  var cases=0,reverseBlocked=0
  for fill in 0...2 { for first in 1...4 { for second in 1...4 {
   let s=LabBoardState(layers:[Array(repeating:0,count:first),Array(repeating:0,count:second),Array(repeating:0,count:fill),[]])
   var q=LabPourQueue();let x=q.move(from:0,to:2,state:s)!
   guard q.reserve(x,state:s),let y=q.move(from:1,to:2,state:s),q.reserve(y,state:s) else { continue }
   cases+=1;if s.applying(y)==nil { reverseBlocked+=1 }
  }}}
  print("Capacity fixtures accepting both: \(cases); current second-first application rejected: \(reverseBlocked)")
 }
}
