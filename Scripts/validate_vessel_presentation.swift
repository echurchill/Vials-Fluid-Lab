import Foundation
import MetalKit
import SwiftUI
import AppKit

@main struct VesselPresentationValidation {
 @MainActor static func main() async throws {
  let device=MTLCreateSystemDefaultDevice()!,library=try device.makeLibrary(URL:URL(fileURLWithPath:CommandLine.arguments[1]))
  let output=URL(fileURLWithPath:CommandLine.arguments[2]);try FileManager.default.createDirectory(at:output,withIntermediateDirectories:true)
  // This offscreen harness deliberately serializes GPU completion for captures.
  func finish(_ command:MTLCommandBuffer) {
   command.waitUntilCompleted();precondition(command.status == .completed)
  }
  // Every renderer and hit target consumes the same role-selected profiles.
  precondition(LabBoardLayout.shapes(for:LabBoardPuzzle.firstSort.initial).allSatisfy {$0 == .testTube})
  precondition(LabBoardLayout.shapes(for:LabBoardPuzzle.secondChance.initial)==[.bulbFlask,.bulbFlask,.testTube,.bulbFlask,.testTube])
  precondition(LabBoardLayout.shapes(for:LabBoardPuzzle.twinProducts.initial)==[.testTube,.testTube,.testTube,.bulbFlask,.bulbFlask,.bulbFlask,.taperedFlask,.taperedFlask,.testTube,.testTube])
  let shared=LabBoardState(layers:[[0],[],[]],capacities:[2,2,2],behavior:.crossover,
      targets:[.init(vial:2,layers:[.init(0)])],apparatus:[.mixer(inputs:[0,1],output:2),.modifier(id:1,chamber:0,direction:.heavier),.modifier(id:2,chamber:2,direction:.lighter)])
  precondition(LabBoardLayout.shapes(for:shared)==[.taperedFlask,.bulbFlask,.testTube],"Role precedence changed")
  var helpers=LabBoardPuzzle.firstSort.initial.addingHelper()!
  let helper=helpers.helpers[0]
  precondition(LabBoardLayout.shapes(for:helpers).last == .teaCup)
  helpers=helpers.upgradingHelper(helper)!
  precondition(LabBoardLayout.shapes(for:helpers).last == .coffeeMug)
  helpers=helpers.upgradingHelper(helper)!
  precondition(LabBoardLayout.shapes(for:helpers).last == .waterJug)
  let classicLayout=LabClassicLayout(size:CGSize(width:1024,height:640),vesselCount:5)
  let classicProfile=LabBoardLayout.profiles(state:LabBoardPuzzle.firstSort.initial)[0]
  let ordinaryHit=classicLayout.hitRect(0,profile:classicProfile)
  let helperHit=classicLayout.hitRect(0,profile:classicProfile,includesHandle:true)
  let valveHit=classicLayout.hitRect(0,profile:classicProfile,includesValveLid:true)
  precondition(abs(ordinaryHit.midX-classicLayout.base(0).x)<0.001,"Ordinary Classic highlight shifted off center")
  precondition(helperHit.minX==ordinaryHit.minX && helperHit.maxX>ordinaryHit.maxX,"Helper Classic hit area missed its handle")
  precondition(valveHit.minY<ordinaryHit.minY && valveHit.maxY==ordinaryHit.maxY,"Valve highlight missed its physical lid")
  precondition(!LabBoardLayout.usesTwoRows(portrait:true,count:7) && LabBoardLayout.usesTwoRows(portrait:true,count:8))
  precondition(!LabBoardLayout.usesTwoRows(portrait:false,count:12))
  let portraitLayout=LabClassicLayout(size:CGSize(width:650,height:1000),vesselCount:12,twoRows:true)
  precondition(portraitLayout.rows.map(\.count)==[6,6])
  precondition(portraitLayout.base(0).y<portraitLayout.base(6).y,"Portrait A–F row must sit above G–L")
  precondition(!portraitLayout.hitRect(0,profile:classicProfile).intersects(portraitLayout.hitRect(6,profile:classicProfile)),"Portrait rows overlap")
  let reusable=try LabBoardRenderer(device:device,library:library)
  let reference=LabVesselProfile(name:"Reference",height:2.35,knots:LabVesselShape.testTube.knots).usableVolume
  for shape in LabVesselShape.allCases {
   for capacity in 1...8 {
    let profile=LabBoardLayout.profiles(capacities:[capacity],shapes:[shape])[0]
    precondition(abs(profile.height-2.35*sqrt(Float(capacity)/4))<0.00001 && profile.depthScale==1)
    precondition(abs(profile.usableVolume-reference*Float(capacity)/4)<0.0001,"Capacity scaling changed")
   }
  }
  for puzzle in LabBoardPuzzle.allCases {
   let initial=puzzle.initial,shapes=LabBoardLayout.shapes(for:initial),expected=LabBoardLayout.profiles(state:initial)
   precondition(!shapes.contains(.pearFlask),"Pear must remain reserved")
   reusable.reset(state:initial)
   let planar=LabFluid2D(game:LabBoardGame(state:initial))
   for i in expected.indices {
    precondition(reusable.profiles[i].radii==expected[i].radii && reusable.profiles[i].height==expected[i].height)
    precondition(planar.profiles[i].source.radii==expected[i].radii && planar.profiles[i].height==expected[i].height)
   }
   var state=initial
   for operation in puzzle.authoredRoute(from:initial) ?? [] {
    state=state.applying(operation)!
    precondition(LabBoardLayout.shapes(for:state)==shapes,"Role silhouette changed during play")
   }
  }
  // Same capacities, different roles: invalidate cached meshes and particle seeds.
  for state in [LabBoardState(layers:[[0],[],[]],capacities:[2,2,2]),shared,LabBoardState(layers:[[0],[],[]],capacities:[2,2,2])] {
   reusable.reset(state:state)
   let expected=LabBoardLayout.profiles(state:state)
   precondition(reusable.profiles.map(\.radii)==expected.map(\.radii),"Stale same-capacity role meshes")
  }
  print("PASS role mapping: 39 boards, shared-role precedence, fixed shapes through routes, seven silhouettes across capacities 1–8, renderer parity and same-capacity cache changes");fflush(stdout)
  let crossRowState=LabBoardState(layers:[[],[1,2],[2,3],[3,4],[4,5],[5,0],[0,1],[]],capacities:Array(repeating:2,count:8))
  let crossRowProfiles=LabBoardLayout.profiles(state:crossRowState)
  let crossRowHomes=LabBoardLayout.homes(count:8,twoRows:true)
  let safeTravelY=(crossRowHomes.map(\.y).max() ?? 0)+(crossRowProfiles.map(\.height).max() ?? 0)+0.34
  for move in [LabBoardMove(source:6,destination:0,parcels:[0],color:0),LabBoardMove(source:0,destination:7,parcels:[0],color:0)] {
   let vessels=LabBoardLayout.vessels(profiles:crossRowProfiles,capacities:crossRowState.capacities,move:move,time:0.70,tilt:0,cutoffTilt:nil,cutoffElapsed:0,returnElapsed:nil,twoRows:true)
   precondition(vessels[move.source].world.columns.3.y>=safeTravelY,"Cross-row 3D travel dropped into a resting row")
  }
  print("PASS cross-row travel clearance");fflush(stdout)
  var planarCrossRow=LabFluid2D(game:LabBoardGame(state:crossRowState))
  planarCrossRow.quickMotion=true;planarCrossRow.setTwoRowLayout(true)
  let crossRowMove=planarCrossRow.game.state.move(from:6,to:0)!
  precondition(planarCrossRow.begin(crossRowMove))
  for _ in 0..<1800 where planarCrossRow.busy {planarCrossRow.advance(deltaTime:1/60,speed:1)}
  precondition(!planarCrossRow.busy && planarCrossRow.game.moveCount==1 && planarCrossRow.game.state.stacks[0].count==1,"Cross-row 2D pour did not commit")
  print("PASS adaptive portrait layout: balanced rows and bidirectional safe travel; 2D cross-row pour committed");fflush(stdout)
  // A tall receiver can be logically full while its last physical settle leaves
  // a visible notch under the completion cap. Exercise the live concurrent 2D
  // path and require the newly sealed seven-unit vial to use its canonical fill.
  let tallCompletion=LabBoardState(layers:[[4],[4,4,4,4,4,4],[]],capacities:[1,7,1])
  let tallSave=LabComparisonSave(presentation:.fluid2D,pace:.quick,puzzle:.firstSort,
    games:[LabBoardPuzzle.firstSort.rawValue:LabBoardGame(state:tallCompletion)])
  let tallSession=FluidBoardSession(defaults:nil,device:device,library:library,restoredSave:tallSave,allowsConcurrentPours:true)
  let tallMove=tallSession.state.move(from:0,to:1)!
  precondition(tallSession.begin(tallMove,automaticClock:false))
  for _ in 0..<1800 where tallSession.busy {await tallSession.advanceConcurrent(deltaTime:1/60)}
  precondition(!tallSession.busy && tallSession.state.isComplete(1),"Tall 2D completion did not commit")
  let tallPacked=tallSession.fluid2D.canonicalSeed(for:tallSession.state)
  for i in tallPacked.indices where tallPacked[i].owner==1 {
   let actual=tallSession.fluid2D.particles[i],expected=tallPacked[i]
   precondition(actual.owner==expected.owner && actual.inBulk && simd_distance(actual.position,expected.position)<0.00001,
     "Completed tall 2D vial retained a noncanonical surface")
  }
  print("PASS completed tall 2D vial: canonical surface meets the cap after concurrent-capable play");fflush(stdout)
  let course45=LabSortingCourseBoard.level(45)!
  let course45BandBytes=course45.initial.stacks.count*course45.initial.colors.count*MemoryLayout<LabBoardBand>.stride
  precondition(course45BandBytes>4096 && course45BandBytes==7520,"Course 45 no longer exercises the large layer table")
  let largeTargetDescriptor=MTLTextureDescriptor.texture2DDescriptor(pixelFormat:.bgra8Unorm_srgb,width:900,height:600,mipmapped:false)
  largeTargetDescriptor.usage=[.renderTarget,.shaderRead];largeTargetDescriptor.storageMode = .shared
  let largeTarget=device.makeTexture(descriptor:largeTargetDescriptor)!
  for destination in [8,9] {
   reusable.reset(state:course45.initial)
   precondition(reusable.begin(from:5,to:destination),"Course 45 F→\(destination == 8 ? "I":"J") is no longer legal")
   finish(reusable.encodeFrame(target:largeTarget,deltaTime:1/60))
  }
  print("PASS Course 45 large-band Metal upload: F→I and F→J encoded without the 4 KB setBytes assertion");fflush(stdout)
  let staticOnly=CommandLine.arguments.contains("--static-only")
  func capture(_ session:FluidBoardSession,_ mode:LabBoardPresentation,_ name:String,_ width:Int,_ height:Int,_ orbit:Float=0.12) throws {
   session.updateAdaptiveLayout(portrait:height>width)
   let cg:CGImage
   if mode == .fluid {
    let descriptor=MTLTextureDescriptor.texture2DDescriptor(pixelFormat:.bgra8Unorm_srgb,width:width,height:height,mipmapped:false)
    descriptor.usage=[.renderTarget,.shaderRead];descriptor.storageMode = .shared
    let texture=device.makeTexture(descriptor:descriptor)!,renderer=session.renderer!,oldOrbit=renderer.orbit
    renderer.orbit=orbit;renderer.encodeFrame(target:texture,deltaTime:0).waitUntilCompleted();renderer.orbit=oldOrbit
    let bitmap=NSBitmapImageRep(bitmapDataPlanes:nil,pixelsWide:width,pixelsHigh:height,bitsPerSample:8,samplesPerPixel:4,hasAlpha:true,isPlanar:false,colorSpaceName:.deviceRGB,bitmapFormat:[],bytesPerRow:width*4,bitsPerPixel:32)!
    texture.getBytes(bitmap.bitmapData!,bytesPerRow:width*4,from:MTLRegionMake2D(0,0,width,height),mipmapLevel:0)
    for i in stride(from:0,to:width*height*4,by:4) {let b=bitmap.bitmapData![i];bitmap.bitmapData![i]=bitmap.bitmapData![i+2];bitmap.bitmapData![i+2]=b};cg=bitmap.cgImage!
   } else {
    let content:AnyView=mode == .classic ? AnyView(LabClassicBoardView(state:session.state,pour:session.classicPour,additionalPours:session.concurrentClassicPours,twoRows:session.twoRowLayout)):AnyView(LabPlanarSurface(display:session.planarDisplay,twoRows:session.twoRowLayout))
    cg=ImageRenderer(content:content.frame(width:CGFloat(width),height:CGFloat(height)).background(Color(red:0.026,green:0.043,blue:0.06))).cgImage!
   }
   try NSBitmapImageRep(cgImage:cg).representation(using:.png,properties:[:])!.write(to:output.appendingPathComponent(name+".png"))
  }
  func requireVisible3DLiquid(_ session:FluidBoardSession,_ label:String) {
   guard let renderer=session.renderer else {preconditionFailure("Missing 3D renderer for \(label)")}
   let samples=renderer.particleSamples(),vessels=renderer.currentVessels,profiles=renderer.profiles
   precondition(samples.count==session.state.colors.count*LabBoardRenderer.particlesPerUnit,"Particle inventory changed after \(label)")
   var owners=[Int](repeating:-1,count:session.state.colors.count)
   for (owner,stack) in session.state.stacks.enumerated() {for parcel in stack {owners[parcel]=owner}}
   for particle in samples {
    let parcel=Int(particle.visual.y),owner=owners[parcel]
    precondition(owner>=0 && Int(particle.position.w)==owner,"Particle ownership changed after \(label)")
    let local=(vessels[owner].inverseWorld*SIMD4(particle.position.xyz,1)).xyz
    let y=min(profiles[owner].height,max(0,local.y)),radius=profiles[owner].radius(at:y)+0.10
    precondition(local.y >= -0.10 && local.y <= profiles[owner].height+0.10 && simd_length(SIMD2(local.x,local.z))<=radius,
      "3D liquid remained outside its reflowed vessel after \(label)")
   }
  }
  func requireFilled3DEnvelopes(_ session:FluidBoardSession,_ label:String) {
   let renderer=session.renderer!,samples=renderer.particleSamples(),vessels=renderer.currentVessels
   for owner in session.state.stacks.indices where !session.state.stacks[owner].isEmpty {
    let owned=samples.filter {Int($0.position.w)==owner}
    precondition(owned.count==session.state.stacks[owner].count*LabBoardRenderer.particlesPerUnit,"Wrong particle count in vial \(owner) after \(label)")
    let maximum=owned.map {(vessels[owner].inverseWorld*SIMD4($0.position.xyz,1)).y}.max()!
    let expected=renderer.profiles[owner].height(for:renderer.profiles[owner].usableVolume*Float(session.state.stacks[owner].count)/Float(session.state.capacity(owner)))
    precondition(maximum>expected*0.80,"Collapsed 3D fill in vial \(owner) after \(label): \(maximum) vs \(expected)")
   }
  }
  let course45Session=FluidBoardSession(defaults:nil,device:device,library:library,
    restoredSave:LabComparisonSave(presentation:.fluid,pace:.quick,puzzle:.firstSort,sortingCourseBoard:course45,
      games:[course45.saveKey:LabBoardGame(state:course45.initial)]),allowsConcurrentPours:true)
  for (source,destination) in [(5,8),(4,8),(5,9),(4,9),(2,9),(1,9),(3,2)] {
   let move=course45Session.state.move(from:source,to:destination)!
   let expected=course45Session.state.applying(move)!
   precondition(course45Session.begin(move,automaticClock:false))
   for _ in 0..<1800 where course45Session.busy {await course45Session.advanceConcurrent(deltaTime:1/60)}
   precondition(!course45Session.busy,"Course 45 reproduction did not finish \(source)→\(destination)")
   precondition(course45Session.state==expected,"Course 45 reproduction rejected \(source)→\(destination): \(course45Session.notice)")
   requireVisible3DLiquid(course45Session,"Course 45 \(source)→\(destination)")
   requireFilled3DEnvelopes(course45Session,"Course 45 \(source)→\(destination)")
  }
  precondition(course45Session.state.stacks.map(\.count)==[4,5,6,7,3,4,6,6,2,4],"Course 45 reproduction diverged from the reported state")
  print("PASS Course 45 seven-move 3D reproduction: all vial fills intact and D→C committed");fflush(stdout)
  let course45FarSession=FluidBoardSession(defaults:nil,device:device,library:library,
    restoredSave:LabComparisonSave(presentation:.fluid,pace:.quick,puzzle:.firstSort,sortingCourseBoard:course45,
      games:[course45.saveKey:LabBoardGame(state:course45.initial)]),allowsConcurrentPours:true)
  let farMove=course45FarSession.state.move(from:3,to:9)!
  let farExpected=course45FarSession.state.applying(farMove)!
  precondition(course45FarSession.begin(farMove,automaticClock:false),"Course 45 D→J is no longer legal")
  for _ in 0..<1800 where course45FarSession.busy {await course45FarSession.advanceConcurrent(deltaTime:1/60)}
  precondition(!course45FarSession.busy,"Course 45 D→J did not finish")
  precondition(course45FarSession.state==farExpected,"Course 45 D→J rolled back: \(course45FarSession.notice)")
  requireVisible3DLiquid(course45FarSession,"Course 45 D→J")
  requireFilled3DEnvelopes(course45FarSession,"Course 45 D→J")
  print("PASS Course 45 eight-unit source pours: D→C and D→J committed without spills");fflush(stdout)
  for mode in LabBoardPresentation.allCases {
   let session=FluidBoardSession(defaults:nil,device:device,library:library,
     restoredSave:LabComparisonSave(presentation:mode,pace:.quick,puzzle:.firstSort))
   session.addHelper()
   if mode == .fluid {requireVisible3DLiquid(session,"adding the first helper")}
   try capture(session,mode,"helper-\(mode.rawValue)-tea",1000,650)
   let index=session.state.helpers[0]
   session.upgradeHelper(index)
   if mode == .fluid {requireVisible3DLiquid(session,"upgrading to a mug")}
   try capture(session,mode,"helper-\(mode.rawValue)-mug",1000,650)
   session.upgradeHelper(index);session.addHelper()
   if mode == .fluid {requireVisible3DLiquid(session,"adding the second helper")}
   try capture(session,mode,"helper-\(mode.rawValue)-jug-tea",1000,650)
   if mode == .fluid {
    session.undo();requireVisible3DLiquid(session,"undoing the second helper")
    session.undo();requireVisible3DLiquid(session,"undoing the jug upgrade")
   }
  }
  let finalCourse=LabSortingCourseBoard.level(LabSortingCourseBoard.levelCount)!
  var crowded=finalCourse.initial.addingHelper()!
  let firstHelper=crowded.helpers[0]
  crowded=crowded.upgradingHelper(firstHelper)!.upgradingHelper(firstHelper)!.addingHelper()!
  precondition(crowded.stacks.count==12 && crowded.helperName(firstHelper)=="Water jug")
  for mode in LabBoardPresentation.allCases {
   let save=LabComparisonSave(presentation:mode,pace:.quick,puzzle:.firstSort,sortingCourseBoard:finalCourse,
     games:[finalCourse.saveKey:LabBoardGame(state:crowded)])
   let session=FluidBoardSession(defaults:nil,device:device,library:library,restoredSave:save)
   if mode == .fluid {requireVisible3DLiquid(session,"opening the final course board with two helpers")}
   try capture(session,mode,"course-50-helpers-\(mode.rawValue)-landscape",1200,650)
   try capture(session,mode,"course-50-helpers-\(mode.rawValue)-portrait",650,1000)
   precondition(session.twoRowLayout,"Crowded portrait board did not enter two-row layout")
  }
  let emptyValve=LabBoardState(layers:[[0],[1],[]],capacities:[1,1,1],
    rules:[.normal,.normal,.receiveOnly],valvePigments:[nil,nil,1])
  for mode in LabBoardPresentation.allCases {
   let save=LabComparisonSave(presentation:mode,pace:.quick,puzzle:.valveCircuit,
     games:[LabBoardPuzzle.valveCircuit.rawValue:LabBoardGame(state:emptyValve)])
   let session=FluidBoardSession(defaults:nil,device:device,library:library,restoredSave:save)
   precondition(session.state.stacks[2].isEmpty && session.state.valvePigment(2)==1)
   try capture(session,mode,"valve-keyed-empty-\(mode.rawValue)",1000,650)
  }
  for mode in LabBoardPresentation.allCases {
   for puzzle in [LabBoardPuzzle.measuredBatch,.heavyLanding,.fiveStreams,.secondChance,.twinProducts] {
    let session=FluidBoardSession(defaults:nil,device:device,library:library,
      restoredSave:LabComparisonSave(presentation:mode,pace:.quick,puzzle:puzzle),allowsConcurrentPours:true)
    let name="\(mode.rawValue)-\(puzzle.rawValue)"
    try capture(session,mode,name+"-ready",1200,650)
    try capture(session,mode,name+"-portrait",650,1000)
    if mode == .fluid {try capture(session,mode,name+"-angled",1200,650,0.4)}
    if staticOnly {continue}
    for profile in session.fluid2D.profiles {
     for step in 0...64 {
      let units=Float(step)*Float(profile.capacity)/64
      let expected=profile.source.height(for:profile.source.usableVolume*units/Float(profile.capacity))
      precondition(abs(profile.level(units)-expected)<0.005,"Cross-mode fill mismatch")
     }
    }
    // Complete the small/large/mixer sequence, including final target caps.
    // Large Sorting fixtures use the shared overlap regression separately.
    if puzzle == .fiveStreams {continue}
    let route=puzzle.authoredRoute(from:session.state)!
    for (index,operation) in route.enumerated() {
     switch operation {
     case .activate(let activation): session.activateApparatus(activation.apparatusID,animated:false)
     case .pour(let move):
      let previous=session.moveCount
      precondition(session.begin(move,automaticClock:false))
      var seen=Set<String>()
      for tick in 0..<1800 where session.busy {
       await session.advanceConcurrent(deltaTime:1/60)
       let phase=session.phase
       if seen.insert(phase).inserted || tick%20==0 {
        if index<2 {try capture(session,mode,"\(name)-move\(index)-\(tick)",1000,600)}
       }
      }
      precondition(!session.busy && session.moveCount==previous+1,"Stuck/rejected \(name) \(index): \(session.notice)")
      print("\(name) operation \(index) completed");fflush(stdout)
     }
    }
    precondition(session.solved,"Route not solved: \(name)")
    try capture(session,mode,name+"-solved",1200,650)
   }
  }
  print(staticOnly ? "Static vessel presentation passed.":"Vessel presentation and complete small-capacity routes passed.")
 }
}
