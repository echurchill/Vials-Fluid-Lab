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
  let reservedState=LabBoardState(layers:[[0,0,0],[0,0,0],[],[]])
  var reservations=LabPourQueue();let firstReserved=reservations.move(from:0,to:2,state:reservedState)!
  require(reservations.reserve(firstReserved,state:reservedState),"first model reservation")
  let smallReserved=reservations.move(from:1,to:2,state:reservedState)!
  require(reservations.reserve(smallReserved,state:reservedState) && smallReserved.amount==1,"partial model reservation")
  let reversed=reservedState.applyingReserved(smallReserved)!.applyingReserved(firstReserved)!
  require(reversed.stacks[2].count==4 && reversed.stacks[1].count==2,"reverse completion changed reserved amount")
  reservations.finish(reservations.items[0].id)
  require(reservations.projected(reservedState).stacks[2].count==1,"failed first transfer enlarged second reservation")
  print("PASS: exact reservation, reverse completion and failed earlier reservation")
  let device=MTLCreateSystemDefaultDevice()!
  let library=try device.makeLibrary(URL:URL(fileURLWithPath:CommandLine.arguments[1]))
  for profile in LabBoardLayout.profiles(capacities:[3,4,5,6]) {
   let cap=labCapMesh(profile)
   require((cap.map(\.position.y).min() ?? -1)>profile.height,"3D completion cap intrudes into liquid headspace")
  }
  print("PASS: 3D completion caps remain outside the vial cavity")
  let guidedSave=LabComparisonSave(presentation:.fluid2D,pace:.quick,puzzle:.valveCircuit,games:[:])
  let guided=FluidBoardSession(defaults:nil,device:device,library:library,restoredSave:guidedSave)
  let guidedRoute=guided.state.solution()!
  guided.hint()
  while guided.findingHint { try await Task.sleep(for:.milliseconds(5)) }
  require(guided.selected==guidedRoute[0].source && guided.hintTarget==guidedRoute[0].destination,"initial hint differed from solved route")
  require(guided.begin(guidedRoute[0],automaticClock:false),"guided move did not begin")
  for _ in 0..<900 where guided.busy { guided.advance2D(deltaTime:1/60) }
  require(!guided.busy,"guided move did not finish")
  guided.hint()
  require(!guided.findingHint && guided.selected==guidedRoute[1].source && guided.hintTarget==guidedRoute[1].destination,"next hint replanned instead of continuing its route")
  require(!(guidedRoute[1].source==guidedRoute[0].destination && guidedRoute[1].destination==guidedRoute[0].source),"solved hint route immediately reversed")
  print("PASS: hint retains and advances one solved route")
  // Exact state reported from the live Valve Circuit board. A fresh search
  // after H→D chooses the legal but useless D→H undo, while the already-solved
  // route continues F→A. The production board enables concurrent pours, so it
  // must retain the route when the hinted pour begins from an idle queue.
  let circularState=LabBoardState(
   layers:[[1,3],[0,0,0,0,0],[],[4,1,3,2,2],[1],[3,1,4,0,3,3],[3,3,3,3,3],[2,4,3,2,2]],
   capacities:[5,6,3,6,4,6,5,5],
   rules:[.normal,.normal,.normal,.normal,.receiveOnly,.normal,.receiveOnly,.normal])
  let circularSave=LabComparisonSave(presentation:.fluid2D,pace:.quick,puzzle:.valveCircuit,
   games:[LabBoardPuzzle.valveCircuit.rawValue:LabBoardGame(state:circularState)])
  let liveGuided=FluidBoardSession(defaults:nil,device:device,library:library,restoredSave:circularSave,allowsConcurrentPours:true)
  let liveRoute=circularState.solution()!
  require(liveRoute[0].source==7 && liveRoute[0].destination==3,"reported circular-hint fixture changed")
  liveGuided.hint()
  while liveGuided.findingHint {try await Task.sleep(for:.milliseconds(5))}
  require(liveGuided.begin(liveRoute[0],automaticClock:false),"live hinted move did not begin")
  for _ in 0..<900 where liveGuided.busy {await liveGuided.advanceConcurrent(deltaTime:1/60)}
  require(!liveGuided.busy,"live hinted move did not finish")
  liveGuided.hint()
  require(!liveGuided.findingHint && liveGuided.selected==liveRoute[1].source && liveGuided.hintTarget==liveRoute[1].destination,
   "live board discarded its route and suggested the inverse move")
  require(!(liveGuided.selected==3 && liveGuided.hintTarget==7),"live board repeated D→H after H→D")
  print("PASS: live concurrent-capable board does not circularly undo a followed hint")
  // Exact Level 16 report: B and C pour Petal into the receive-only G vial.
  // Once all destination particles arrive, the transaction must remain active
  // for visible settling frames instead of snapping the final volume into view.
  let valveSave=LabComparisonSave(presentation:.fluid,pace:.quick,puzzle:.valveCircuit,
   games:[LabBoardPuzzle.valveCircuit.rawValue:LabBoardGame(state:LabBoardPuzzle.valveCircuit.initial)])
  let valve=FluidBoardSession(defaults:nil,device:device,library:library,restoredSave:valveSave,allowsConcurrentPours:true)
  let bToG=valve.availableMove(from:1,to:6)!,cToG:LabBoardMove
  require(valve.begin(bToG,automaticClock:false),"Level 16 B→G did not begin")
  cToG=valve.availableMove(from:2,to:6)!
  require(valve.begin(cToG,automaticClock:false),"Level 16 C→G did not join shared receiver")
  await valve.advanceConcurrent(deltaTime:1/60)
  require(valve.active3DSimulationParticleCount==5*LabBoardRenderer.particlesPerUnit,
   "Level 16 shared lane did not compact to the five participating units: \(valve.active3DSimulationParticleCount)")
  let finalG=Set(valve.state.stacks[6]+bToG.parcels+cToG.parcels)
  var visibleSettleFrames=0,lastSettlePositions:[SIMD3<Float>]?=nil,maxSettleStep:Float=0
  var heldSources:[SIMD3<Float>]?=nil,maxHeldSourceStep:Float=0
  var postSettleReceiver:[SIMD3<Float>]?=nil,postSettleFrames=0,maxPostSettleStep:Float=0,maxReturnTravel:Float=0
  var wasSettling=false
  for _ in 0..<1800 where valve.busy {
   await valve.advanceConcurrent(deltaTime:1/60)
   let settling=valve.fluidFinalSettling
   let positions=valve.renderer!.particleSamples().filter {finalG.contains(Int($0.visual.y))}.map(\.position.xyz)
   let sources=[1,2].map {valve.renderer!.currentVessels[$0].world.columns.3.xyz}
   if settling {
    if let previous=lastSettlePositions,previous.count==positions.count {
     maxSettleStep=max(maxSettleStep,zip(previous,positions).map(simd_distance).max() ?? 0)
    }
    if let previous=heldSources {maxHeldSourceStep=max(maxHeldSourceStep,zip(previous,sources).map(simd_distance).max() ?? 0)}
    lastSettlePositions=positions
    heldSources=sources
    visibleSettleFrames+=1
   } else if wasSettling && valve.busy {
    postSettleReceiver=positions;heldSources=sources;postSettleFrames=1
   } else if let final=postSettleReceiver,valve.busy {
    maxPostSettleStep=max(maxPostSettleStep,zip(final,positions).map(simd_distance).max() ?? 0)
    if let heldSources {maxReturnTravel=max(maxReturnTravel,zip(heldSources,sources).map(simd_distance).max() ?? 0)}
    postSettleFrames+=1
   }
   wasSettling=settling
  }
  require(!valve.busy && valve.moveCount==2 && valve.state.isComplete(6),"Level 16 B+C→G did not complete")
  require(visibleSettleFrames>=12,"Level 16 final fluid volume snapped instead of settling: \(visibleSettleFrames) frames")
  require(maxHeldSourceStep<0.001,"Level 16 sources left before final fluid settled: \(maxHeldSourceStep)")
  require(postSettleFrames>=12 && maxReturnTravel>0.5,"Level 16 sources did not visibly return after settling")
  require(maxPostSettleStep<0.001,"Level 16 receiver changed while sources returned: \(maxPostSettleStep)")
  let finalSamples=valve.renderer!.particleSamples().filter {finalG.contains(Int($0.visual.y))}
  let centerSurface=(finalSamples.map(\.position.y).max() ?? 0)-LabBoardLayout.homes(count:8)[6].y
  let headspace=valve.renderer!.profiles[6].height-centerSurface-valve.renderer!.renderedParticleRadius
  require(headspace>0.12,"Level 16 completed receiver has no visible headspace: \(headspace)")
  print("PASS: Level 16 B+C→G settles for \(visibleSettleFrames) held-source frames, returns for \(postSettleFrames) stable-receiver frames, visible headspace \(headspace)")
  // Exact recording follow-up: A pours its two Tide units into C but retains
  // three lower units. Those retained particles must remain inside the raised
  // source and travel home with it; they must not wait at A's home position for
  // the descending glass to reveal them.
  var partialSourceState=LabBoardPuzzle.valveCircuit.initial
  partialSourceState=partialSourceState.applying(partialSourceState.move(from:1,to:6)!)!
  partialSourceState=partialSourceState.applying(partialSourceState.move(from:2,to:6)!)!
  let partialSourceSave=LabComparisonSave(presentation:.fluid,pace:.quick,puzzle:.valveCircuit,
   games:[LabBoardPuzzle.valveCircuit.rawValue:LabBoardGame(state:partialSourceState)])
  let partialSource=FluidBoardSession(defaults:nil,device:device,library:library,restoredSave:partialSourceSave,allowsConcurrentPours:true)
  let aToC=partialSource.availableMove(from:0,to:2)!
  let retainedA=Set(partialSource.state.stacks[0]).subtracting(aToC.parcels)
  let finalC=Set(partialSource.state.stacks[2]+aToC.parcels)
  require(partialSource.begin(aToC,automaticClock:false),"Level 16 A→C did not begin")
  var sawPartialSettle=false,partialReturnFrames=0,maxRetainedLocalDrift:Float=0,maxPartialReceiverStep:Float=0,minRetainedInside=1.0
  var retainedBaseline:[SIMD3<Float>]?=nil,receiverBaseline:[SIMD3<Float>]?=nil,heldSource:SIMD3<Float>?=nil,maxPartialReturnTravel:Float=0
  for _ in 0..<1800 where partialSource.busy {
   await partialSource.advanceConcurrent(deltaTime:1/60)
   let settling=partialSource.fluidFinalSettling
   if settling {sawPartialSettle=true}
   else if sawPartialSettle && partialSource.busy {
    let vessel=partialSource.renderer!.currentVessels[0]
    let retained=partialSource.renderer!.particleSamples().filter {retainedA.contains(Int($0.visual.y))}
    let local=retained.map {(vessel.inverseWorld*SIMD4($0.position.xyz,1)).xyz}
    let receiver=partialSource.renderer!.particleSamples().filter {finalC.contains(Int($0.visual.y))}.map(\.position.xyz)
    if let baseline=retainedBaseline {maxRetainedLocalDrift=max(maxRetainedLocalDrift,zip(baseline,local).map(simd_distance).max() ?? 0)}
    else {retainedBaseline=local;receiverBaseline=receiver;heldSource=vessel.world.columns.3.xyz}
    if let baseline=receiverBaseline {maxPartialReceiverStep=max(maxPartialReceiverStep,zip(baseline,receiver).map(simd_distance).max() ?? 0)}
    if let heldSource {maxPartialReturnTravel=max(maxPartialReturnTravel,simd_distance(heldSource,vessel.world.columns.3.xyz))}
    let profile=partialSource.renderer!.profiles[0]
    let inside=local.filter {p in
     let y=min(profile.height,max(0,p.y)),radius=profile.radius(at:y)+0.18
     return p.y > -0.12 && p.y < profile.height+0.12 && hypot(p.x,p.z)<radius
    }.count
    minRetainedInside=min(minRetainedInside,Double(inside)/Double(max(1,local.count)))
    partialReturnFrames+=1
   }
  }
  require(!partialSource.busy && partialSource.moveCount==1 && partialSource.state.isComplete(2),"Level 16 A→C did not complete")
  require(partialReturnFrames>=12 && maxPartialReturnTravel>0.5,"Level 16 partial source did not visibly return")
  require(maxRetainedLocalDrift<0.001 && minRetainedInside>0.99,"Level 16 retained A liquid detached during return: drift \(maxRetainedLocalDrift), inside \(minRetainedInside)")
  require(maxPartialReceiverStep<0.001,"Level 16 completed C changed while A returned: \(maxPartialReceiverStep)")
  print("PASS: Level 16 A→C retains three source units through \(partialReturnFrames) return frames while completed C stays stable")
  func make(_ state:LabBoardState,_ mode:LabBoardPresentation)->FluidBoardSession {
   let save=LabComparisonSave(presentation:mode,pace:.quick,puzzle:.firstSort,games:["firstSort":LabBoardGame(state:state)])
   return FluidBoardSession(defaults:nil,device:device,library:library,restoredSave:save,allowsConcurrentPours:true)
  }
  if CommandLine.arguments.contains("--partial-stress") {
   var failures=0
   for round in 0..<12 {
    let session=make(LabBoardState(layers:[[0,0,0],[0,0,0],[],[]]),.fluid)
    require(session.begin(session.availableMove(from:0,to:2)!,automaticClock:false),"partial first")
    require(session.begin(session.availableMove(from:1,to:2)!,automaticClock:false),"partial second")
    for tick in 0..<1800 where session.busy {
     await session.advanceConcurrent(deltaTime:1/60)
     if CommandLine.arguments.contains("--inspect"),tick==350 {
      let missing=session.renderer!.particleSamples().filter {Int($0.visual.y)==5 && Int($0.position.w) != 2}
      print("UNCAPTURED \(round) count=\(missing.count) guided=\(missing.filter {$0.visual.w>0}.count)")
      for p in missing.prefix(50) {print("particle \(p.position) velocity=\(p.velocity)")};fflush(stdout)
     }
    }
    let passed = !session.busy && session.moveCount==2
    print("PARTIAL \(round) passed=\(passed) \(String(describing:session.performance.context["lastRejectedPour"]))");fflush(stdout)
    if !passed {failures+=1}
   }
   require(failures==0,"partial stress failures=\(failures)");return
  }
  if CommandLine.arguments.contains("--autoplay") {
   let mode=LabBoardPresentation(rawValue:CommandLine.arguments.last!) ?? .fluid2D
   let session=make(LabBoardPuzzle.greenArrival.initial,mode)
   var failures=0,rounds=0
   for tick in 0..<10000 {
    if session.solved { rounds+=1;if rounds==2 {break};session.reset();session.changePuzzle(.greenArrival) }
    if tick%6==0,session.pourQueue.items.count<session.state.stacks.count {
     let projected=session.pourQueue.projected(session.state),receivers=Set(session.pourQueue.active.map {$0.move.destination})
     let options=session.state.stacks.indices.flatMap {a in session.state.stacks.indices.compactMap {b in session.availableMove(from:a,to:b)}}.sorted {receivers.contains($0.destination) && !receivers.contains($1.destination)}
     if let move=options.first(where: { !(projected.stacks[$0.destination].isEmpty && Set(projected.stacks[$0.source].map {projected.colors[$0]}).count==1) && projected.applying($0)?.solution() != nil}) {
      print("START tick=\(tick) \(move.source)→\(move.destination) units=\(move.amount)");fflush(stdout)
      _=session.begin(move,automaticClock:false)
     }
    }
    let prior=session.pourQueue.items
    await session.advanceConcurrent(deltaTime:1/60)
    if mode == .fluid {
     let samples=session.renderer!.particleSamples()
     require(samples.allSatisfy {[$0.position.x,$0.position.y,$0.position.z,$0.position.w,$0.visual.y].allSatisfy(\.isFinite)},"nonfinite 3D particle")
     let counts=Dictionary(grouping:samples,by:{Int($0.visual.y)})
     require(counts.count==session.state.colors.count && counts.values.allSatisfy {$0.count==LabBoardRenderer.particlesPerUnit},"3D parcel inventory changed")
     let moving=Set(session.pourQueue.items.flatMap { $0.move.parcels })
     for (owner,stack) in session.state.stacks.enumerated() {
      for id in stack where !moving.contains(id) {require(counts[id]!.allSatisfy {Int($0.position.w)==owner},"3D stale parcel ownership: \(id)")}
     }
    }
    for item in prior where !session.pourQueue.items.contains(where:{$0.id==item.id}) {
     let failed=item.move.parcels.contains {session.state.stacks[item.move.source].contains($0)}
     print("END tick=\(tick) \(item.move.source)→\(item.move.destination) failed=\(failed) \(failed ? String(describing:session.performance.context["lastRejectedPour"]):"")");fflush(stdout)
     if failed {failures+=1}
    }
   }
   require(rounds==2 && failures==0,"autoplay \(mode) rounds=\(rounds) failures=\(failures)")
   print("PASS: two autoplay solutions \(mode)");return
  }
  let output=URL(fileURLWithPath:CommandLine.arguments.count>2 ? CommandLine.arguments[2]:"/private/tmp/vials-concurrent-captures")
  try FileManager.default.createDirectory(at:output,withIntermediateDirectories:true)
  func capture(_ session:FluidBoardSession,_ mode:LabBoardPresentation,_ suffix:String="") throws {
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
   try NSBitmapImageRep(cgImage:cg).representation(using:.png,properties:[:])!.write(to:output.appendingPathComponent(mode.rawValue+suffix+".png"))
  }
  for mode in LabBoardPresentation.allCases {
   let state=LabBoardState(layers:[[0,1,1,1],[0,1],[],[],[2,2],[]],capacities:[6,5,3,4,6,6])
   let session=make(state,mode)
   let a=session.availableMove(from:0,to:2)!,b=session.availableMove(from:1,to:3)!
   require(session.begin(a,automaticClock:false) && session.begin(b,automaticClock:false),"independent reservations \(mode)")
   require(session.availableMove(from:0,to:4)==nil && session.availableMove(from:2,to:5)==nil,"busy source/receiver selectable")
   let c=session.availableMove(from:4,to:5)!
   require(session.begin(c,automaticClock:false),"third reservation rejected")
   for _ in 0..<45 { await session.advanceConcurrent(deltaTime:1/60) }
   try capture(session,mode)
   require(session.pourQueue.active.count==3,"expected three active lanes \(mode)")
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
   require(maxActive==3,"three-way concurrency")
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
   require(shared.pourQueue.active.count==2 && shared.pourQueue.items.count==2,"shared receiver must start both pours")
   var overlapFrames=0
   for step in 0..<1800 where shared.busy {
    await shared.advanceConcurrent(deltaTime:1/60)
    let overlap:Bool
    if mode == .classic { overlap=shared.concurrentClassicPours.filter {$0.progress>0 && $0.progress<1}.count==2 }
    else if mode == .fluid2D { overlap=[first,second].allSatisfy { move in shared.fluid2D.particles.contains {move.parcels.contains($0.parcel) && $0.owner<0} } }
    else { let samples=shared.renderer!.particleSamples();overlap=[first,second].allSatisfy {move in samples.contains {move.parcels.contains(Int($0.visual.y)) && $0.position.w<0}} }
    if overlap {overlapFrames+=1;if overlapFrames==10 {try capture(shared,mode,"-shared")}}
    if step==120 {
     shared.togglePause();let frozen=shared.fluid2D.particles,poses=shared.renderer?.currentVessels.map(\.world)
     await shared.advanceConcurrent(deltaTime:4)
     require(shared.fluid2D.particles==frozen && (poses==nil || poses==shared.renderer?.currentVessels.map(\.world)),"shared pause advanced")
     shared.togglePause()
    }
   }
   require(overlapFrames>0,"no actual simultaneous streams \(mode)")
   print("PASS: \(mode.rawValue) simultaneous stream frames: \(overlapFrames)")
   require(shared.solved && shared.state.stacks[2].count==4 && shared.moveCount==2,"shared receiver completion \(mode): \(shared.notice)")
   shared.undo();require(shared.moveCount==1 && shared.state.stacks[2].count==2,"shared receiver undo")
   // Join the same receiver after the first source is already tilting.
   let late=make(LabBoardState(layers:[[0,0],[0,0],[],[]]),mode)
   let lateFirst=late.availableMove(from:1,to:2)!
   require(late.begin(lateFirst,automaticClock:false),"late first")
   for _ in 0..<90 {await late.advanceConcurrent(deltaTime:1/60)}
   let lateSecond=late.availableMove(from:0,to:2)!
   require(late.begin(lateSecond,automaticClock:false),"late receiver reservation")
   for _ in 0..<1800 where late.busy {await late.advanceConcurrent(deltaTime:1/60)}
   require(late.solved && late.moveCount==2,"late shared receiver join failed \(mode): \(late.notice)")
   let limited=make(LabBoardState(layers:[[0,0,0],[0,0,0],[],[]]),mode)
   require(limited.begin(limited.availableMove(from:0,to:2)!,automaticClock:false),"first capacity reservation")
   let remainder=limited.availableMove(from:1,to:2)!
   require(remainder.amount==1 && limited.begin(remainder,automaticClock:false),"truncated capacity reservation")
   for _ in 0..<1800 where limited.busy { await limited.advanceConcurrent(deltaTime:1/60) }
   require(!limited.busy && limited.moveCount==2 && limited.state.stacks[2].count==4 && limited.state.stacks[1].count==2,"reserved partial pour overflow \(mode): busy=\(limited.busy) moves=\(limited.moveCount) stacks=\(limited.state.stacks) notice=\(limited.notice) arrived=\(limited.fluid2D.arrived) diagnostic=\(String(describing:limited.performance.context["lastRejectedPour"]))")
   // An accepted move must still start if an earlier completion sorts the board.
   let finishing=make(LabBoardState(layers:[[0,0],[0,0],[1,1,1,1],[],[2,2,2,2],[]]),mode)
   for pair in [(0,1),(2,3),(4,5)] { require(finishing.begin(finishing.availableMove(from:pair.0,to:pair.1)!,automaticClock:false),"endgame reservation") }
   for _ in 0..<2200 where finishing.busy { await finishing.advanceConcurrent(deltaTime:1/60) }
   require(finishing.solved && finishing.moveCount==3 && finishing.state.stacks[5].count==4,"sorted intermediate board cancelled accepted pour \(mode)")
   let reset=make(state,mode);require(reset.begin(a,automaticClock:false) && reset.begin(b,automaticClock:false),"reset setup")
   require(reset.begin(c,automaticClock:false),"reset queued setup")
   await reset.advanceConcurrent(deltaTime:1/60);reset.reset();await reset.advanceConcurrent(deltaTime:10)
   require(!reset.busy && reset.moveCount==0 && reset.state==LabBoardPuzzle.firstSort.initial,"reset left lanes alive")
   print("PASS: \(mode.rawValue) three-way overlapping lanes, dependency guards, shared receiver overlap, pause/suspend, checkpoint, partial completion, undo and reset")
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
