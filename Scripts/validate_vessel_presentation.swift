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
  let reusable=try LabBoardRenderer(device:device,library:library)
  let reference=LabVesselProfile(name:"Reference",height:2.35,knots:LabVesselShape.testTube.knots).usableVolume
  for shape in LabVesselShape.allCases {
   for capacity in 1...6 {
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
  print("PASS role mapping: 39 boards, shared-role precedence, fixed shapes through routes, seven silhouettes/capacities, renderer parity and same-capacity cache changes");fflush(stdout)
  let staticOnly=CommandLine.arguments.contains("--static-only")
  func capture(_ session:FluidBoardSession,_ mode:LabBoardPresentation,_ name:String,_ width:Int,_ height:Int,_ orbit:Float=0.12) throws {
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
    let content:AnyView=mode == .classic ? AnyView(LabClassicBoardView(state:session.state,pour:session.classicPour,additionalPours:session.concurrentClassicPours)):AnyView(LabPlanarSurface(display:session.planarDisplay))
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
    let d=MTLTextureDescriptor.texture2DDescriptor(pixelFormat:.bgra8Unorm_srgb,width:700,height:455,mipmapped:false)
    d.storageMode = .shared;d.usage=[.renderTarget,.shaderRead]
    let texture=device.makeTexture(descriptor:d)!
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
  print("Vessel presentation and complete small-capacity routes passed.")
 }
}
