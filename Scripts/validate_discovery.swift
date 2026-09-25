import Foundation
import MetalKit
import SwiftUI
import AppKit

@main struct DiscoveryValidation {
 @MainActor static func main() throws {
  let device=MTLCreateSystemDefaultDevice()!,library=try device.makeLibrary(URL:URL(fileURLWithPath:CommandLine.arguments[1]))
  let output=URL(fileURLWithPath:CommandLine.arguments[2]);try FileManager.default.createDirectory(at:output,withIntermediateDirectories:true)
  func save(_ cg:CGImage,_ name:String) throws {try NSBitmapImageRep(cgImage:cg).representation(using:.png,properties:[:])!.write(to:output.appendingPathComponent(name+".png"))}
  func capture<V:View>(_ view:V,_ name:String) throws {try save(ImageRenderer(content:view.frame(width:1000,height:700).background(Color(red:0.026,green:0.043,blue:0.06))).cgImage!,name)}
  let desc=MTLTextureDescriptor.texture2DDescriptor(pixelFormat:.bgra8Unorm_srgb,width:1000,height:700,mipmapped:false)
  desc.storageMode = .shared;desc.usage=[.renderTarget,.shaderRead]
  let texture=device.makeTexture(descriptor:desc)!
  func capture3D(_ renderer:LabBoardRenderer,_ name:String) throws {
   renderer.encodeFrame(target:texture,deltaTime:0).waitUntilCompleted()
   let bitmap=NSBitmapImageRep(bitmapDataPlanes:nil,pixelsWide:1000,pixelsHigh:700,bitsPerSample:8,samplesPerPixel:4,hasAlpha:true,isPlanar:false,colorSpaceName:.deviceRGB,bitmapFormat:[],bytesPerRow:4000,bitsPerPixel:32)!
   texture.getBytes(bitmap.bitmapData!,bytesPerRow:4000,from:MTLRegionMake2D(0,0,1000,700),mipmapLevel:0)
   for i in stride(from:0,to:2800000,by:4) {let b=bitmap.bitmapData![i];bitmap.bitmapData![i]=bitmap.bitmapData![i+2];bitmap.bitmapData![i+2]=b}
   try save(bitmap.cgImage!,name)
  }
  var checked=0
  for puzzle in LabDiscipline.discovery.levels {
   let initial=puzzle.initial
   precondition(initial.hasUnknown && initial.knownParcels==Set(initial.stacks.compactMap(\.last)))
   // Changing hidden identities must not change the visible hint choice or batch size.
   var other=initial
   for parcel in other.colors.indices where !other.isKnown(parcel) {other.colors[parcel]=(other.colors[parcel]+1)%3}
   precondition(initial.discoveryHint()==other.discoveryHint(),"Hint leaked an unknown pigment")
   precondition(initial.stacks.indices.allSatisfy { i in initial.stacks.indices.allSatisfy { j in initial.move(from:i,to:j)==other.move(from:i,to:j) } },"Legal moves leaked an unknown pigment")
   let first=initial.discoveryHint()!,after=initial.applying(first)!
   var game=LabBoardGame(state:initial)
   precondition(game.begin(from:first.source,to:first.destination)==first && game.commit(first))
   let discovered=game.state.knownParcels!
   precondition(game.undo() && game.state.knownParcels!.isSuperset(of:discovered),"Undo erased knowledge")
   let decoded=try JSONDecoder().decode(LabBoardGame.self,from:JSONEncoder().encode(game))
   precondition(decoded.state==game.state,"Save erased discoveries")
   for mode in LabBoardPresentation.allCases {
    let session=FluidBoardSession(defaults:nil,device:device,library:library,restoredSave:LabComparisonSave(presentation:mode,pace:.quick,puzzle:puzzle),allowsConcurrentPours:false)
    precondition(!session.concurrentPoursEnabled && !session.canComparePour)
    precondition(session.accessibility(0).contains("Unknown liquid"))
    func frame(_ stage:String) throws {
     let name="\(mode.rawValue)-\(puzzle.rawValue)-\(stage)"
     if mode == .classic {try capture(LabClassicBoardView(state:session.state,pour:session.classicPour,transformation:session.transformation),name)}
     else if mode == .fluid2D {try capture(LabFluid2DView(engine:session.fluid2D),name)}
     else {try capture3D(session.renderer!,name)}
    }
    try frame("before")
    precondition(session.begin(first,automaticClock:false))
    var sawReveal=false
    for _ in 0..<2400 where session.busy {
     if let reveal=session.transformation {
      if !sawReveal {
       precondition(reveal.isRevealing && reveal.parcels==after.knownParcels!.subtracting(initial.knownParcels!))
       let time=reveal.time
       session.togglePause();session.advanceTransformation(deltaTime:1)
       precondition(session.transformation!.time==time,"Reveal ignored pause")
       session.togglePause()
       let positions=mode == .fluid ? session.renderer!.particleSamples().map(\.position):[]
       let planar=session.fluid2D.particles.map(\.position)
       session.advanceTransformation(deltaTime:0.05)
       if mode == .fluid {precondition(positions==session.renderer!.particleSamples().map(\.position),"Reveal moved 3D particles")}
       if mode == .fluid2D {precondition(planar==session.fluid2D.particles.map(\.position),"Reveal moved 2D particles")}
       try frame("reveal");sawReveal=true
      }
      session.advanceTransformation(deltaTime:1/60)
     } else if mode == .classic {session.advanceClassic(deltaTime:1/60)}
     else if mode == .fluid2D {session.advance2D(deltaTime:1/60)}
     else {session.renderer!.advanceSimulation(deltaTime:1/60)}
    }
    precondition(!session.busy && session.state==after && sawReveal,"Discovery pour or reveal did not complete")
    try frame("after")
    let save=try JSONDecoder().decode(LabComparisonSave.self,from:session.checkpointData())
    precondition(save.games[puzzle.rawValue]!.state==after)
    session.undo();precondition(session.state.stacks==initial.stacks && session.state.knownParcels!.isSuperset(of:after.knownParcels!))
    session.reset();precondition(session.state.stacks==initial.stacks && session.state.knownParcels!.isSuperset(of:after.knownParcels!))
    let replay=session.state.move(from:first.source,to:first.destination)!
    precondition(session.begin(replay,automaticClock:false));session.reset();session.advanceTransformation(deltaTime:1)
    precondition(!session.busy && session.state.stacks==initial.stacks,"Reset left a pending reveal")
    let route=session.state.solution()!
    for move in route {
     let expected=session.state.applying(move)!
     precondition(session.begin(move,automaticClock:false))
     for _ in 0..<2400 where session.busy {
      if session.transformation != nil {session.advanceTransformation(deltaTime:1/60)}
      else if mode == .classic {session.advanceClassic(deltaTime:1/60)}
      else if mode == .fluid2D {session.advance2D(deltaTime:1/60)}
      else {session.renderer!.advanceSimulation(deltaTime:1/60)}
     }
     precondition(!session.busy && session.state==expected,"Full Discovery route diverged")
    }
    precondition(session.solved && !session.state.hasUnknown)
    session.reset(keepingDiscoveries:false);precondition(session.state==initial,"Explicit fresh reset retained knowledge")
    checked+=1;print("PASS \(mode.rawValue) \(puzzle.rawValue): knowledge, pause, save, undo, reset, stationary reveal");fflush(stdout)
   }
  }
  // Boundary even when the hidden portion has the very same true pigment.
  let same=LabBoardState(layers:[[0,0],[]],capacities:[2,2],behavior:.discovery,obscured:true)
  precondition(same.move(from:0,to:1)!.amount==1 && !same.isComplete(0))
  // Particle masks intentionally overlap at a band boundary. The band above
  // must render last, regardless of its pigment number; unknown gray is 36 and
  // previously always rendered over a known color above it.
  let course45=LabSortingCourseBoard.level(45)!.initial
  let planar=LabFluid2D(game:LabBoardGame(state:course45)),owner=7
  let groups=Dictionary(grouping:planar.particles.filter {$0.owner==owner}) { $0.color }
  let order=planar.renderOrder(owner:owner,groups:groups)
  let hidden=36,known=course45.visualDye(course45.stacks[owner].last!)
  precondition(order.firstIndex(of:hidden)!<order.firstIndex(of:known)!,"Hidden 2D liquid would overdraw the known top band")
  try capture(LabFluid2DView(engine:planar),"fluid2D-course-45-band-order")
  // Course 45 exposed a second source-side artifact after a four-unit pour:
  // the two retained layers could keep a sparse, disturbed particle layout.
  // The final settle must restore their canonical solid bands without
  // repacking successful arrivals in the receiving vial.
  var retained=LabBoardState(layers:[[0,3,1,1,1,1],[1,1],[]],capacities:[6,6,6],behavior:.discovery,obscured:true)
  retained.knownParcels!.formUnion(retained.stacks[0][1...])
  var disturbed=LabFluid2D(game:LabBoardGame(state:retained));disturbed.quickMotion=true
  let largeDeparture=disturbed.game.state.move(from:0,to:1)!
  precondition(largeDeparture.amount==4 && disturbed.begin(largeDeparture))
  for _ in 0..<2400 where disturbed.busy {disturbed.advance(deltaTime:1/60,speed:1.6)}
  let expected=retained.applying(largeDeparture)!,canonical=disturbed.canonicalSeed(for:expected)
  precondition(!disturbed.busy && disturbed.game.state==expected,"Large Discovery departure did not commit")
  let retainedParcels=Set(expected.stacks[0])
  let settled=disturbed.particles.indices.filter {retainedParcels.contains(disturbed.particles[$0].parcel)}.allSatisfy {
    disturbed.particles[$0]==canonical[$0]
  }
  precondition(settled,"Retained 2D Discovery layers did not return to solid canonical bands")
  try capture(LabFluid2DView(engine:disturbed),"fluid2D-discovery-large-source-settled")
  print("PASS: \(checked) Discovery cases; unknown-identity hint/move invariance, known-batch boundary, bottom-to-top bands and solid retained source layers")
 }
}
