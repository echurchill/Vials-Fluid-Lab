import Foundation
import MetalKit
import SwiftUI
import AppKit

@main @MainActor struct LabConcurrencyValidation {
 static func check(_ value:@autoclosure()->Bool,_ message:String="",file:StaticString=#fileID,line:UInt=#line) {if !value() {print("FAIL \(file):\(line) \(message)");fflush(stdout);fatalError(message)}}
 static func main() async throws {
  let device=MTLCreateSystemDefaultDevice()!,library=try device.makeLibrary(URL:URL(fileURLWithPath:CommandLine.arguments[1]))
  let output=URL(fileURLWithPath:CommandLine.arguments[2]);try FileManager.default.createDirectory(at:output,withIntermediateDirectories:true)
  func make(_ state:LabBoardState,_ puzzle:LabBoardPuzzle,_ mode:LabBoardPresentation)->FluidBoardSession {
   FluidBoardSession(defaults:nil,device:device,library:library,restoredSave:LabComparisonSave(presentation:mode,pace:.quick,puzzle:puzzle,games:[puzzle.rawValue:LabBoardGame(state:state)]),allowsConcurrentPours:true)
  }
  func drain(_ s:FluidBoardSession) async {
   for _ in 0..<2400 where s.busy {await s.advanceConcurrent(deltaTime:1/60)}
   check(!s.busy,"Stuck \(s.presentation) \(s.discipline) \(s.notice)")
   check(s.error==nil)
  }
  func capture(_ s:FluidBoardSession,_ name:String) throws {
   let cg:CGImage
   if s.presentation == .fluid {
    let d=MTLTextureDescriptor.texture2DDescriptor(pixelFormat:.bgra8Unorm_srgb,width:1000,height:700,mipmapped:false);d.storageMode = .shared;d.usage=[.renderTarget,.shaderRead]
    let t=device.makeTexture(descriptor:d)!;s.renderer!.capExclusions=Set(s.activeMoves.flatMap {[$0.source,$0.destination]});s.renderer!.encodeFrame(target:t,deltaTime:0).waitUntilCompleted()
    let b=NSBitmapImageRep(bitmapDataPlanes:nil,pixelsWide:1000,pixelsHigh:700,bitsPerSample:8,samplesPerPixel:4,hasAlpha:true,isPlanar:false,colorSpaceName:.deviceRGB,bitmapFormat:[],bytesPerRow:4000,bitsPerPixel:32)!
    t.getBytes(b.bitmapData!,bytesPerRow:4000,from:MTLRegionMake2D(0,0,1000,700),mipmapLevel:0)
    for i in stride(from:0,to:2800000,by:4) {let x=b.bitmapData![i];b.bitmapData![i]=b.bitmapData![i+2];b.bitmapData![i+2]=x};cg=b.cgImage!
   } else if s.presentation == .classic {
    cg=ImageRenderer(content:LabClassicBoardView(state:s.state,pour:nil,additionalPours:s.concurrentClassicPours,reveals:s.concurrentReveals).frame(width:1000,height:700).background(Color.black)).cgImage!
   } else {cg=ImageRenderer(content:LabFluid2DView(engine:s.fluid2D).frame(width:1000,height:700).background(Color.black)).cgImage!}
   try NSBitmapImageRep(cgImage:cg).representation(using:.png,properties:[:])!.write(to:output.appendingPathComponent(name+".png"))
  }
  var count=0
  for mode in LabBoardPresentation.allCases where ProcessInfo.processInfo.environment["LAB_TEST_MODE"].map({$0==mode.rawValue}) ?? true {
   for discipline in LabDiscipline.allCases {
    print("BEGIN \(mode) \(discipline)");fflush(stdout)
    let puzzle=discipline.levels[0]
    let behavior:LabBehavior=discipline == .discovery ? .discovery:(discipline == .density ? .density:(discipline == .crossover ? .crossover:(discipline == .sorting ? .sorting:.mixing)))
    // One receiver shared by unequal batches; a third source waits for a lane.
    let state=LabBoardState(layers:[[0,0],[0],[0],[],[1],[]],capacities:[2,1,1,4,1,1],behavior:behavior,targets:[.init(vial:3,layers:Array(repeating:.init(0),count:4)),.init(vial:5,layers:[.init(1)])])
    let s=make(state,puzzle,mode)
    check(s.concurrentPoursEnabled)
    var expected=state
    for source in [0,1,2] {
     let move=s.availableMove(from:source,to:3)!
     check(s.begin(move,automaticClock:false));expected=expected.applyingReserved(move)!
    }
    let other=s.availableMove(from:4,to:5)!;check(s.begin(other,automaticClock:false));expected=expected.applyingReserved(other)!
    check(s.availableMove(from:3,to:0)==nil && s.availableMove(from:0,to:5)==nil)
    await s.advanceConcurrent(deltaTime:1/60)
    check(s.pourQueue.active.count==3 && s.pourQueue.items.count==4,"Two shared lanes plus independent pour expected")
    s.togglePause();let q=s.pourQueue,history=s.moveCount
    for _ in 0..<5 {await s.advanceConcurrent(deltaTime:1)}
    check(s.moveCount==history && s.pourQueue.items.map(\.id)==q.items.map(\.id));s.togglePause()
    s.setSuspended(true);await s.advanceConcurrent(deltaTime:1);check(s.moveCount==history);s.setSuspended(false)
    await drain(s)
    if s.state.stacks != expected.stacks {print(s.performance.context);fflush(stdout)}
    check(s.state.stacks==expected.stacks,"Completion order diverged \(mode) \(discipline): \(s.state.stacks) vs \(expected.stacks)")
    check(s.moveCount==4,"Lost/double commit")
    let saved=try JSONDecoder().decode(LabComparisonSave.self,from:s.checkpointData());check(saved.games[puzzle.rawValue]!.state==s.state)
    for _ in 0..<4 {s.undo()};check(s.state.stacks==state.stacks)
    count+=1;print("PASS \(mode) \(discipline): shared/queued/independent, reservation order, pause/suspend, save, undo");fflush(stdout)
   }
   // Simultaneous different densities and equal-density different pigments.
   for equal in [false,true] {
    let state=LabBoardState(layers:[[8,8],[0],[4]],capacities:[2,1,4],densityLayers:[[.heavy,.heavy],[equal ? .heavy:.medium],[.light]],behavior:.density)
    let s=make(state,.heavyLanding,mode)
    let a=s.availableMove(from:0,to:2)!;check(s.begin(a,automaticClock:false))
    let b=s.availableMove(from:1,to:2)!;check(s.begin(b,automaticClock:false))
    let expected=state.applyingReserved(a)!.applyingReserved(b)!
    var preSettleLanded:Float=0
    for tick in 0..<2400 where s.busy {
     await s.advanceConcurrent(deltaTime:1/60)
     if mode == .fluid,!s.fluidFinalSettling,s.moveCount==0 {
      let renderer=s.renderer!,vessel=renderer.currentVessels[2],profile=renderer.profiles[2]
      let volume=profile.volume(at:profile.height(for:profile.usableVolume)-renderer.renderedParticleRadius)
      let top=profile.height(for:volume*3/4)
      let incoming=Set(a.parcels+b.parcels)
      let landed=renderer.particleSamples().filter {incoming.contains(Int($0.visual.y)) && Int($0.position.w)==2 && (vessel.inverseWorld*SIMD4($0.position.xyz,1)).y<=top+0.10}.count
      preSettleLanded=max(preSettleLanded,Float(landed)/Float(3*LabBoardRenderer.particlesPerUnit))
     }
     if tick==125 {try capture(s,"\(mode)-density-\(equal ? "ties":"mixed")")}
    }
    check(!s.busy && s.state==expected && s.moveCount==2,"Density shared pour failed \(mode) equal=\(equal) \(s.notice)")
    if mode == .fluid {check(preSettleLanded>=0.90,"Density only resolved at final settle: \(preSettleLanded)")}
    try capture(s,"\(mode)-density-\(equal ? "ties":"mixed")-finished")
    print("PASS \(mode): simultaneous \(equal ? "equal-density pigments":"different densities")");fflush(stdout)
   }
   // Independent reveals must not wait for another pour and must freeze on pause.
   let hidden=LabBoardState(layers:[[1,0],[2,0],[],[],[1],[]],capacities:[2,2,2,2,1,1],behavior:.discovery,obscured:true)
   let d=make(hidden,.firstReveal,mode)
   let a=d.availableMove(from:0,to:2)!;check(d.begin(a,automaticClock:false))
   for _ in 0..<100 {await d.advanceConcurrent(deltaTime:1/60)}
   let b=d.availableMove(from:1,to:3)!;check(d.begin(b,automaticClock:false))
   var overlap=false,seen=Set<Int>()
   for _ in 0..<2400 where d.busy {
    await d.advanceConcurrent(deltaTime:1/60)
    if !d.concurrentReveals.isEmpty {
     seen.formUnion(d.concurrentReveals.keys)
     if !d.pourQueue.items.isEmpty && !overlap {
      overlap=true;try capture(d,"\(mode)-discovery-overlap")
      let before=d.concurrentReveals;d.togglePause();await d.advanceConcurrent(deltaTime:10);check(d.concurrentReveals==before);d.togglePause()
      check(d.availableMove(from:0,to:5)==nil,"Revealing source was usable early")
      let unrelated=d.availableMove(from:4,to:5)!;check(d.begin(unrelated,automaticClock:false),"Reveal blocked unrelated pour")
     }
    }
   }
   check(!d.busy && overlap && seen==Set([hidden.stacks[0][0],hidden.stacks[1][0]]),"Independent reveal lost or blocked")
   let knowledge=d.state.knownParcels!;d.undo();check(d.state.knownParcels!.isSuperset(of:knowledge))
   print("PASS \(mode): overlapping Discovery reveal/pour, pause, unrelated input, retained knowledge");fflush(stdout)
   // Apparatus is globally serialized with pours, including programmatic begin.
   let machineState=LabBoardState(layers:[[8],[4],[],[0],[]],capacities:[1,1,2,1,1],behavior:.mixing,targets:[.init(vial:2,layers:[.init(1),.init(1)]),.init(vial:3,layers:[.init(0)])],apparatus:[.mixer(inputs:[0,1],output:2)])
   let m=make(machineState,.warmBlend,mode)
   let move=m.availableMove(from:3,to:4)!;check(m.begin(move,automaticClock:false));m.activateApparatus(0,automaticClock:false)
   check(m.transformation==nil && m.moveCount==0);await drain(m)
   m.activateApparatus(0,automaticClock:false);check(m.transformation != nil)
   let reverse=m.state.move(from:4,to:3)!;check(!m.begin(reverse,automaticClock:false) && !m.canTap(4))
   for _ in 0..<500 where m.busy {m.advanceTransformation(deltaTime:1/60)}
   check(!m.busy && m.moveCount==2)
   check(m.begin(reverse,automaticClock:false));m.reset();await m.advanceConcurrent(deltaTime:1)
   check(!m.busy && m.concurrentReveals.isEmpty && m.state==LabBoardPuzzle.warmBlend.initial)
   print("PASS \(mode): machine exclusivity, post-machine pour and reset cancellation");fflush(stdout)
  }
  print("PASS all lab concurrency checks (\(count) shared-receiver lab/presentation cases plus density, Discovery, machine tests)")
 }
}
