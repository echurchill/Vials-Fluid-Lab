import Foundation
@main struct SharedSolverValidation {
 static func main() async {
  let puzzle=LabBoardPuzzle(rawValue:CommandLine.arguments.dropFirst().first ?? "greenArrival") ?? .greenArrival
  var game=LabBoardGame(state:puzzle.initial),queue=LabPourQueue()
  var initial=LabFluid2D(game:game);initial.quickMotion=true
  let worker=LabConcurrent2DWorker(initial)
  var count=0,failures=0
  for tick in 0..<10000 {
   if game.state.solved && !queue.busy {break}
   if tick%6==0,queue.items.count<2 {
    let projected=queue.projected(game.state),receivers=Set(queue.active.map {$0.move.destination})
    let options=game.state.stacks.indices.flatMap {a in game.state.stacks.indices.compactMap {b in queue.move(from:a,to:b,state:game.state)}}.sorted {receivers.contains($0.destination) && !receivers.contains($1.destination)}
    if let move=options.first(where:{!(projected.stacks[$0.destination].isEmpty && Set(projected.stacks[$0.source].map {projected.colors[$0]}).count==1) && projected.applying($0)?.solution() != nil}) {
     _=queue.reserve(move,state:game.state)
     print("START \(tick) \(move.source)→\(move.destination) units=\(move.amount) stacks=\(game.state.stacks)");fflush(stdout)
    }
   }
   let starts=queue.startReady()
   let frame=await worker.advance(game:game,starts:starts,deltaTime:1/60,speed:1.6)
   for result in frame.finished {
    let move=queue.items.first {$0.id==result.id}!.move
    let committed=result.committed && game.commitReserved(move)
    if !committed {failures+=1}
    print("END \(tick) \(move.source)→\(move.destination) committed=\(committed) \(result.diagnostic)");fflush(stdout)
    queue.finish(result.id);count+=1
   }
   var owners=[Int](repeating:-1,count:game.state.colors.count)
   for (owner,stack) in game.state.stacks.enumerated() {for id in stack {owners[id]=owner}}
   var counts=[Int](repeating:0,count:owners.count)
   for particle in frame.display.particles {
    counts[particle.parcel]+=1
    let pending=queue.active.first {$0.move.parcels.contains(particle.parcel)}?.move
    let valid=particle.owner==owners[particle.parcel] || (pending != nil && (particle.owner == -1 || particle.owner==pending!.destination))
    precondition(valid,"Foreign parcel ownership changed in \(puzzle.rawValue), tick \(tick), parcel \(particle.parcel)")
   }
   precondition(counts.allSatisfy {$0==LabFluid2D.particlesPerUnit},"Particle inventory changed")
  }
  print("RESULT solved=\(game.state.solved) moves=\(count) failures=\(failures)")
  if !game.state.solved || failures>0 {exit(1)}
 }
}
