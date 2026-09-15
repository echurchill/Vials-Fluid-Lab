import Foundation
import MetalKit
import SwiftUI
import AppKit

@main struct ConcurrentValidation {
 @MainActor static func main() async throws {
  func require(_ value:Bool,_ message:String) { if !value { fatalError(message) } }
  var clock=LabAnimationClock()
  clock.setRunning(true,at:10);require(clock.elapsed(at:13)==3,"clock running")
  clock.setRunning(false,at:13);require(clock.elapsed(at:1000)==3,"paused clock advanced")
  clock.setRunning(true,at:1000);require(clock.elapsed(at:1000)==3,"resume jumped")
  require(clock.elapsed(at:1002)==5,"resume stopped advancing")
  clock.setRunning(false,at:1002);clock.setRunning(false,at:1100)
  require(clock.elapsed(at:1200)==5,"repeated suspension advanced clock")
  print("PASS: idle clock pause, long suspension, exact resume, repeated suspension")
  let device=MTLCreateSystemDefaultDevice()!
  let library=try device.makeLibrary(URL:URL(fileURLWithPath:CommandLine.arguments[1]))
  func make(_ state:LabBoardState,_ mode:LabBoardPresentation)->FluidBoardSession {
   let save=LabComparisonSave(presentation:mode,pace:.quick,puzzle:.firstSort,games:["firstSort":LabBoardGame(state:state)])
   return FluidBoardSession(defaults:nil,device:device,library:library,restoredSave:save,allowsConcurrentPours:true)
  }
  let output=URL(fileURLWithPath:CommandLine.arguments.count>2 ? CommandLine.arguments[2]:"/private/tmp/vials-concurrent-captures")
  try FileManager.default.createDirectory(at:output,withIntermediateDirectories:true)
  func capture(_ session:FluidBoardSession,_ mode:LabBoardPresentation) throws {
   let cg:CGImage
   if mode == .fluid {
    let descriptor=MTLTextureDescriptor.texture2DDescriptor(pixelFormat:.bgra8Unorm_srgb,width:1100,height:600,mipmapped:false)
    descriptor.usage=[.renderTarget,.shaderRead];descriptor.storageMode = .shared
    let texture=device.makeTexture(descriptor:descriptor)!
    session.renderer!.encodeFrame(target:texture,deltaTime:0).waitUntilCompleted()
    let bitmap=NSBitmapImageRep(bitmapDataPlanes:nil,pixelsWide:1100,pixelsHigh:600,bitsPerSample:8,samplesPerPixel:4,hasAlpha:true,isPlanar:false,colorSpaceName:.deviceRGB,bitmapFormat:[],bytesPerRow:4400,bitsPerPixel:32)!
    texture.getBytes(bitmap.bitmapData!,bytesPerRow:4400,from:MTLRegionMake2D(0,0,1100,600),mipmapLevel:0)
    for i in stride(from:0,to:1100*600*4,by:4) { let blue=bitmap.bitmapData![i];bitmap.bitmapData![i]=bitmap.bitmapData![i+2];bitmap.bitmapData![i+2]=blue }
    cg=bitmap.cgImage!
   } else {
    let content:AnyView=mode == .classic ? AnyView(LabClassicBoardView(state:session.state,pour:nil,additionalPours:session.concurrentClassicPours)):AnyView(LabPlanarSurface(display:session.planarDisplay))
    let render=ImageRenderer(content:content.frame(width:1100,height:600).background(Color(red:0.026,green:0.043,blue:0.060)))
    cg=render.cgImage!
   }
   try NSBitmapImageRep(cgImage:cg).representation(using:.png,properties:[:])!.write(to:output.appendingPathComponent(mode.rawValue+".png"))
  }
  for mode in LabBoardPresentation.allCases {
   let state=LabBoardState(layers:[[0,1,1,1],[0,1],[],[],[2,2],[]])
   let session=make(state,mode)
   let a=session.availableMove(from:0,to:2)!,b=session.availableMove(from:1,to:3)!
   require(session.begin(a,automaticClock:false) && session.begin(b,automaticClock:false),"independent reservations \(mode)")
   require(session.availableMove(from:0,to:4)==nil && session.availableMove(from:2,to:5)==nil,"busy source/receiver selectable")
   let c=session.availableMove(from:4,to:5)!
   require(session.begin(c,automaticClock:false),"third reservation rejected")
   for _ in 0..<45 { await session.advanceConcurrent(deltaTime:1/60) }
   try capture(session,mode)
   require(session.pourQueue.active.count==2,"expected two active lanes \(mode)")
   let phases=session.pourQueue.items.map(\.started),particles=session.fluid2D.particles,poses=session.renderer?.currentVessels.map(\.world)
   session.togglePause()
   for _ in 0..<10 { await session.advanceConcurrent(deltaTime:0.5) }
   require(session.pourQueue.items.map(\.started)==phases && session.fluid2D.particles==particles,"pause changed 2D lanes")
   if let poses { require(session.renderer!.currentVessels.map(\.world)==poses,"pause changed 3D lanes") }
   session.togglePause();session.setSuspended(true)
   await session.advanceConcurrent(deltaTime:10)
   require(session.fluid2D.particles==particles,"background advanced lanes")
   session.setSuspended(false)
   let partial=try JSONDecoder().decode(LabComparisonSave.self,from:session.checkpointData())
   require(partial.games["firstSort"]!.state==state && partial.games["firstSort"]!.pending==nil,"save included unfinished transfers")
   var sawPartial=false,maxActive=0
   for _ in 0..<1800 where session.busy {
    await session.advanceConcurrent(deltaTime:1/60)
    maxActive=max(maxActive,session.pourQueue.active.count)
    if session.moveCount>0 && session.busy && !sawPartial {
     sawPartial=true
     let checkpoint=try JSONDecoder().decode(LabComparisonSave.self,from:session.checkpointData())
     require(checkpoint.games["firstSort"]!.state==session.state && checkpoint.games["firstSort"]!.moveCount==session.moveCount && checkpoint.games["firstSort"]!.pending==nil,"partial save lost committed moves or kept reservations")
    }
   }
   let expected=state.applying(a)!.applying(b)!.applying(c)!
   require(!session.busy && session.state==expected && session.moveCount==3,"independent commit \(mode): \(session.notice)")
   require(maxActive<=2 && sawPartial,"concurrency limit/completion order")
   session.undo();require(session.moveCount==2,"undo completed order")
   let staggered=make(state,mode)
   require(staggered.begin(a,automaticClock:false),"staggered first")
   for _ in 0..<115 { await staggered.advanceConcurrent(deltaTime:1/60) }
   require(staggered.begin(staggered.availableMove(from:1,to:3)!,automaticClock:false),"staggered second")
   for _ in 0..<1500 where staggered.busy { await staggered.advanceConcurrent(deltaTime:1/60) }
   require(staggered.state==state.applying(a)!.applying(b)! && staggered.moveCount==2,"staggered lane captured foreign fluid \(mode)")
   let shared=make(LabBoardState(layers:[[0,0],[0,0],[],[]]),mode)
   let first=shared.availableMove(from:0,to:2)!;require(shared.begin(first,automaticClock:false),"first shared receiver")
   let second=shared.availableMove(from:1,to:2)!;require(shared.begin(second,automaticClock:false),"second shared receiver")
   await shared.advanceConcurrent(deltaTime:1/60)
   require(shared.pourQueue.active.count==1 && shared.pourQueue.items.count==2,"shared receiver must enter in order")
   for _ in 0..<1800 where shared.busy { await shared.advanceConcurrent(deltaTime:1/60) }
   require(shared.solved && shared.state.stacks[2].count==4 && shared.moveCount==2,"shared receiver completion \(mode): \(shared.notice)")
   shared.undo();require(shared.moveCount==1 && shared.state.stacks[2].count==2,"shared receiver undo")
   let limited=make(LabBoardState(layers:[[0,0,0],[0,0,0],[],[]]),mode)
   require(limited.begin(limited.availableMove(from:0,to:2)!,automaticClock:false),"first capacity reservation")
   let remainder=limited.availableMove(from:1,to:2)!
   require(remainder.amount==1 && limited.begin(remainder,automaticClock:false),"truncated capacity reservation")
   for _ in 0..<1800 where limited.busy { await limited.advanceConcurrent(deltaTime:1/60) }
   require(!limited.busy && limited.moveCount==2 && limited.state.stacks[2].count==4 && limited.state.stacks[1].count==2,"reserved partial pour overflow \(mode): busy=\(limited.busy) moves=\(limited.moveCount) stacks=\(limited.state.stacks) notice=\(limited.notice) arrived=\(limited.fluid2D.arrived)")
   // An accepted move must still start if an earlier completion sorts the board.
   let finishing=make(LabBoardState(layers:[[0,0],[0,0],[1,1,1,1],[],[2,2,2,2],[]]),mode)
   for pair in [(0,1),(2,3),(4,5)] { require(finishing.begin(finishing.availableMove(from:pair.0,to:pair.1)!,automaticClock:false),"endgame reservation") }
   for _ in 0..<2200 where finishing.busy { await finishing.advanceConcurrent(deltaTime:1/60) }
   require(finishing.solved && finishing.moveCount==3 && finishing.state.stacks[5].count==4,"sorted intermediate board cancelled accepted pour \(mode)")
   let reset=make(state,mode);require(reset.begin(a,automaticClock:false) && reset.begin(b,automaticClock:false),"reset setup")
   require(reset.begin(c,automaticClock:false),"reset queued setup")
   await reset.advanceConcurrent(deltaTime:1/60);reset.reset();await reset.advanceConcurrent(deltaTime:10)
   require(!reset.busy && reset.moveCount==0 && reset.state==LabBoardPuzzle.firstSort.initial,"reset left lanes alive")
   print("PASS: \(mode.rawValue) overlapping lanes, queue limit, shared receiver order, pause/suspend, checkpoint, partial completion, undo and reset")
  }
  let overflow=make(LabBoardState(layers:[[0,0,0],[0,0,0],[1],[]]),.classic)
  require(overflow.begin(overflow.availableMove(from:0,to:3)!,automaticClock:false),"reserve 3")
  require(overflow.availableMove(from:1,to:3)?.amount==1,"remaining capacity reservation")
  require(overflow.availableMove(from:2,to:3)==nil,"wrong-color reservation")
  print("PASS: projected capacity and color reservations")
  // Exercise the real actor clock: pause/reset can arrive during a worker batch.
  let automatic=make(LabBoardState(layers:[[0,1],[0,1],[],[]]),.fluid2D)
  require(automatic.begin(automatic.availableMove(from:0,to:2)!) && automatic.begin(automatic.availableMove(from:1,to:3)!),"automatic setup")
  try await Task.sleep(for:.milliseconds(120));automatic.togglePause()
  let frozen=automatic.fluid2D.particles
  try await Task.sleep(for:.milliseconds(200))
  require(automatic.fluid2D.particles==frozen,"in-flight worker published through pause")
  automatic.togglePause();try await Task.sleep(for:.milliseconds(100));automatic.reset()
  let resetParticles=automatic.fluid2D.particles
  try await Task.sleep(for:.milliseconds(150))
  require(!automatic.busy && automatic.fluid2D.particles==resetParticles,"cancelled worker resurrected a pour")
  print("PASS: automatic concurrent clock pause and reset during actor work")
 }
}
