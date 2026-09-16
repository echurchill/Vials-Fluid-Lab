import Foundation
import MetalKit

/// Deterministic offscreen workload. Separates controller/solver readback from
/// surface GPU work; it intentionally does not claim compositor frame rate.
@main struct Concurrent3DBenchmark {
 @MainActor static func main() async throws {
  let libraryURL=URL(fileURLWithPath:CommandLine.arguments[1]),output=URL(fileURLWithPath:CommandLine.arguments[2])
  let device=MTLCreateSystemDefaultDevice()!,library=try device.makeLibrary(URL:libraryURL)
  let save=LabComparisonSave(presentation:.fluid,pace:.quick,puzzle:.greenArrival,games:["greenArrival":LabBoardGame(state:LabBoardPuzzle.greenArrival.initial)])
  let session=FluidBoardSession(defaults:nil,device:device,library:library,restoredSave:save,allowsConcurrentPours:true)
  let descriptor=MTLTextureDescriptor.texture2DDescriptor(pixelFormat:.bgra8Unorm_srgb,width:1000,height:600,mipmapped:false)
  descriptor.usage=[.renderTarget,.shaderRead];descriptor.storageMode = .private
  let target=device.makeTexture(descriptor:descriptor)!
  var rows:[[String:Any]]=[],completed=0,failed=0,rounds=0
  for tick in 0..<7000 {
   if session.solved {rounds+=1;if rounds==2 {break};session.reset()}
   var started=false
   if tick%6==0,session.pourQueue.items.count<2 {
    let projected=session.pourQueue.projected(session.state),receivers=Set(session.pourQueue.active.map {$0.move.destination})
    let options=session.state.stacks.indices.flatMap {a in session.state.stacks.indices.compactMap {b in session.availableMove(from:a,to:b)}}.sorted {receivers.contains($0.destination) && !receivers.contains($1.destination)}
    if let move=options.first(where:{!(projected.stacks[$0.destination].isEmpty && Set(projected.stacks[$0.source].map {projected.colors[$0]}).count==1) && projected.applying($0)?.solution() != nil}) {started=session.begin(move,automaticClock:false)}
   }
   let prior=session.pourQueue.items,start=ProcessInfo.processInfo.systemUptime
   await session.advanceConcurrent(deltaTime:1/60)
   let controller=(ProcessInfo.processInfo.systemUptime-start)*1000
   let command=session.renderer!.encodeFrame(target:target,deltaTime:0);command.waitUntilCompleted()
   precondition(command.status == .completed,"GPU frame failed")
   let ended=prior.filter {p in !session.pourQueue.items.contains {$0.id==p.id}}
   for item in ended {completed+=1;if item.move.parcels.contains(where:{session.state.stacks[item.move.source].contains($0)}) {failed+=1}}
   let GPU=max(0,(command.gpuEndTime-command.gpuStartTime)*1000)
   rows.append(["tick":tick,"controllerMs":controller,"surfaceGPUMs":GPU,"started":started,"completed":ended.count,"active":session.pourQueue.active.count])
  }
  func summary(_ values:[Double])->[String:Any] {let v=values.sorted();return v.isEmpty ? ["samples":0]:["samples":v.count,"median":v[v.count/2],"p95":v[min(v.count-1,Int(Double(v.count)*0.95))],"maximum":v.last!]}
  let result:[String:Any]=["scope":"Mac offscreen 1000x600; controller includes solver GPU waits; surface GPU excludes solver and compositor. Two repeated Green arrival solutions.","device":device.name,"rounds":rounds,"completed":completed,"failures":failed,"controllerMs":summary(rows.compactMap {$0["controllerMs"] as? Double}),"startControllerMs":summary(rows.filter {$0["started"] as? Bool == true}.compactMap {$0["controllerMs"] as? Double}),"steadyControllerMs":summary(rows.filter {$0["started"] as? Bool == false && $0["completed"] as? Int == 0}.compactMap {$0["controllerMs"] as? Double}),"surfaceGPUMs":summary(rows.compactMap {$0["surfaceGPUMs"] as? Double}),"frames":rows]
  try JSONSerialization.data(withJSONObject:result,options:[.prettyPrinted,.sortedKeys]).write(to:output)
  print("rounds=\(rounds) completed=\(completed) failures=\(failed)");precondition(rounds==2 && failed==0)
 }
}
