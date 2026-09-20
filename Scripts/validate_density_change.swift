import Foundation
import MetalKit
import SwiftUI
import AppKit

@main struct DensityChangeValidation {
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
  for mode in LabBoardPresentation.allCases {
   for puzzle in LabDiscipline.crossover.levels {
    var state=puzzle.initial
    for (index,operation) in puzzle.authoredRoute(from:state)!.enumerated() {
     let expected=state.applying(operation)!
     defer {state=expected}
     guard case .activate(let activation)=operation,
           state.apparatus.first(where:{$0.id==activation.apparatusID})!.kind == .densityModifier else {continue}
     let saved=LabComparisonSave(presentation:mode,pace:.quick,puzzle:puzzle,games:[puzzle.rawValue:LabBoardGame(state:state)])
     let session=FluidBoardSession(defaults:nil,device:device,library:library,restoredSave:saved,allowsConcurrentPours:true)
     session.reduceTransformationMotion=puzzle == .equalPartners
     session.activateApparatus(activation.apparatusID,automaticClock:false)
     precondition(session.busy && session.transformation != nil && session.state==state && session.moveCount==0)
     session.activateApparatus(activation.apparatusID) // Double activation is ignored.
     let chamber=state.apparatus.first(where:{$0.id==activation.apparatusID})!.inputs[0]
     let original2D=session.fluid2D.particles
     let original3D=mode == .fluid ? session.renderer!.particleSamples():[]
     var sampled=Set<Int>(),last2D:[Lab2DParticle]=[],last3D:[LabParticle]=[]
     var previousOffsets:SIMD2<Float>?
     for tick in 0..<300 where session.busy {
      session.advanceTransformation(deltaTime:1/60)
      if let mix=session.transformation {
       precondition(session.state==state && session.moveCount==0,"Mix committed prematurely")
       precondition(mix.blend>=0 && mix.blend<=1 && mix.isDensityChange)
       precondition(mix.before.stacks==mix.after.stacks && mix.before.colors==mix.after.colors,"Density change altered inventory or pigment")
       let offsets=mix.densityPatternOffsets
       if session.reduceTransformationMotion {precondition(mix.agitation==0 && offsets == .zero)}
       if let previousOffsets {
        precondition(offsets.x>=previousOffsets.x-0.00001 && offsets.y<=previousOffsets.y+0.00001,"Density motifs drifted against their arrow direction")
       }
       previousOffsets=offsets
       if mix.blend==1 {
        let bank=mix.after.densities[mix.after.stacks[mix.output][0]]
        if bank == .light {precondition(offsets.x==0)}
        if bank == .heavy {precondition(offsets.y==0)}
       }
       if tick==20 {
        let before=mix.time,p=mode == .fluid ? session.renderer!.particleSamples().map(\.position):[]
        let planar=session.fluid2D.particles
        session.togglePause();session.advanceTransformation(deltaTime:10)
        precondition(session.transformation!.time==before && session.fluid2D.particles==planar)
        if mode == .fluid {precondition(session.renderer!.particleSamples().map(\.position)==p)}
        session.togglePause();session.setSuspended(true);session.advanceTransformation(deltaTime:10)
        precondition(session.transformation!.time==before);session.setSuspended(false)
        let saved=try JSONDecoder().decode(LabComparisonSave.self,from:session.checkpointData())
        precondition(saved.games[puzzle.rawValue]!.state==state,"Checkpoint included partial mix")
       }
       if mode == .fluid2D {
        let particles=session.fluid2D.particles
        precondition(particles.count==state.colors.count*LabFluid2D.particlesPerUnit)
        precondition(particles.allSatisfy {$0.position.x.isFinite && $0.position.y.isFinite})
        for (old,p) in zip(original2D,particles) {
         precondition(old.owner==p.owner && old.parcel==p.parcel,"Density animation released particles from the chamber")
         if p.owner != chamber {precondition(old==p,"Unrelated 2D fluid moved")}
         else {
          let local=session.fluid2D.pose(chamber).local(p.position),profile=session.fluid2D.profiles[chamber]
          precondition(local.y>=0 && local.y<=profile.level(Float(state.stacks[chamber].count))+0.05 && abs(local.x)<=profile.radius(local.y),"Density animation escaped 2D glass")
          if session.reduceTransformationMotion {precondition(old.position==p.position,"Reduced Motion moved 2D particles")}
         }
        }
        last2D=particles
       }
       if mode == .fluid {
        let particles=session.renderer!.particleSamples()
        precondition(particles.count==state.colors.count*LabBoardRenderer.particlesPerUnit)
        precondition(particles.allSatisfy {$0.position.x.isFinite && $0.position.y.isFinite && $0.position.z.isFinite})
        for (old,p) in zip(original3D,particles) {
         precondition(old.position.w==p.position.w && old.visual.y==p.visual.y,"Density animation changed owners")
         if Int(p.position.w) != chamber {precondition(old.position==p.position && old.velocity==p.velocity,"Unrelated 3D fluid moved")}
         else {
          let local=(session.renderer!.currentVessels[chamber].inverseWorld*SIMD4(p.position.xyz,1)).xyz,profile=session.renderer!.profiles[chamber]
          precondition(local.y>=0 && local.y<=profile.height(for:profile.usableVolume*Float(state.stacks[chamber].count)/Float(state.capacity(chamber)))+0.05 && simd_length(SIMD2(local.x,local.z))<=profile.radius(at:local.y),"Density animation escaped 3D glass")
          if session.reduceTransformationMotion {precondition(old.position==p.position,"Reduced Motion moved 3D particles")}
         }
        }
        last3D=particles
       }
       let stage=Int(mix.time/0.45)
       if [LabBoardPuzzle.weightedOrange,.twinProducts].contains(puzzle),sampled.insert(stage).inserted {
        let name="\(mode.rawValue)-\(puzzle.rawValue)-\(index)-\(stage)"
        if mode == .classic {try capture(LabClassicBoardView(state:session.state,pour:nil,transformation:mix),name)}
        else if mode == .fluid2D {try capture(LabFluid2DView(engine:session.fluid2D),name)}
        else {try capture3D(session.renderer!,name)}
       }
      }
     }
     precondition(!session.busy && session.state==expected && session.moveCount==1,"Mix did not commit exactly once")
     if mode == .fluid2D {
      let drift=zip(last2D,session.fluid2D.particles).map {simd_distance($0.position,$1.position)}.max() ?? 0
      precondition(drift<0.03,"Planar final repack jumped")
     }
     if mode == .fluid {
      let drift=zip(last3D,session.renderer!.particleSamples()).map {simd_distance($0.position.xyz,$1.position.xyz)}.max() ?? 0
      precondition(drift<0.03,"Metal final repack jumped")
     }
     if case .pour(let move)?=puzzle.authoredRoute()?.dropFirst(index+1).first {
      let poured=expected.applying(move)!
      precondition(session.begin(move,automaticClock:false))
      for _ in 0..<1500 where session.busy {
       if mode == .classic {session.advanceClassic(deltaTime:1/60)}
       else if mode == .fluid2D {session.advance2D(deltaTime:1/60)}
       else {session.renderer!.advanceSimulation(deltaTime:1/60)}
      }
      precondition(!session.busy && session.state==poured,"Changed-density fluid cannot be poured afterward")
      session.undo();precondition(session.state==expected)
     }
     session.undo();precondition(session.state==state && session.moveCount==0)
     session.activateApparatus(activation.apparatusID,automaticClock:false)
     session.advanceTransformation(deltaTime:0.05);session.reset();session.advanceTransformation(deltaTime:10)
     precondition(!session.busy && session.state==puzzle.initial && session.moveCount==0,"Reset left a delayed density commit")
     checked+=1
     print("PASS \(mode.rawValue) \(puzzle.rawValue) density operation \(index)");fflush(stdout)
    }
   }
  }
  print("PASS: \(checked) animated density cases; state, particle inventory, pause/suspension, save, double activation, final continuity, undo and reset")
 }
}
