import Foundation
import MetalKit
import SwiftUI
import AppKit

@main struct DensityPourValidation {
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
  let cases:[(String,LabDensity,[LabDensity],Int,LabBehavior)]=[
   ("heavy-through-light",.heavy,[.light],1,.density),
   ("medium-above-heavy",.medium,[.heavy,.light],1,.density),
   ("medium-above-medium",.medium,[.heavy,.medium,.light],1,.density),
   ("heavy-above-heavy",.heavy,[.heavy,.medium,.light],1,.density),
   ("light-floats",.light,[.heavy,.medium,.light],1,.density),
   ("two-heavy-units",.heavy,[.light],2,.density),
   ("crossover-medium",.medium,[.heavy,.medium,.light],1,.crossover)]
  for (name,incoming,residents,amount,behavior) in cases {
   let state=LabBoardState(layers:[Array(repeating:3,count:amount),Array(0..<residents.count)],capacities:[max(2,amount),4],densityLayers:[Array(repeating:incoming,count:amount),residents],behavior:behavior)
   let move=state.move(from:0,to:1)!,after=state.applying(move)!,ids=Set(move.parcels)
   let floor=state.densityInsertionIndex(for:move)
   precondition(floor==residents.filter {$0.order<=incoming.order}.count)
   let layers=state.densityReceiverLayers(for:move,joinedUnits:Float(amount))
   precondition(layers.map(\.parcel)==after.stacks[1],"Visual order must equal canonical stable order")
   for fraction:Float in [0,0.25,0.5,1] {
    let partial=state.densityReceiverLayers(for:move,joinedUnits:Float(amount)*fraction)
    precondition(abs(partial.reduce(0) {$0+$1.units}-Float(residents.count)-Float(amount)*fraction)<0.0001)
   }
   for progress:Float in [0,0.05,0.25,0.5,1] {try capture(LabClassicBoardView(state:state,pour:LabClassicPour(move:move,time:1.6+progress*3.6)),"\(name)-classic-\(progress)")}
   for mode in ["2d","3d"] {
    var planar=LabFluid2D(game:LabBoardGame(state:state));planar.quickMotion=true
    let renderer=try LabBoardRenderer(device:device,library:library);renderer.reset(state:state)
    if mode=="2d" {precondition(planar.begin(move))} else {precondition(renderer.begin(from:0,to:1))}
    var seenCrossing=false,precleanupChecked=false,maxStep:Float=0,previous:[Int:Float]=[:],finalFraction:Float=0
    var captures=Set<Int>()
    for tick in 0..<1500 {
     let busy=mode=="2d" ? planar.busy:renderer.game.pending != nil
     if !busy {break}
     if mode=="2d" {planar.advance(deltaTime:1/60,speed:1)} else {renderer.advanceSimulation(deltaTime:1/60)}
     let profile=renderer.profiles[1],capacity:Float=4
     let volume=mode=="2d" ? profile.usableVolume:profile.volume(at:profile.height(for:profile.usableVolume)-renderer.renderedParticleRadius)
     let floorY=profile.height(for:volume*Float(floor)/capacity),topY=profile.height(for:volume*Float(floor+amount)/capacity)
     var receiving:[(Int,Float)]=[]
     if mode=="2d" {
      receiving=planar.particles.enumerated().filter {$0.element.owner==1 && ids.contains($0.element.parcel)}.map {($0.offset,planar.pose(1).local($0.element.position).y)}
     } else {
      receiving=renderer.particleSamples().enumerated().filter {Int($0.element.position.w)==1 && ids.contains(Int($0.element.visual.y))}.map {($0.offset,(renderer.currentVessels[1].inverseWorld*SIMD4($0.element.position.xyz,1)).y)}
     }
     for (i,y) in receiving {if let old=previous[i] {maxStep=max(maxStep,old-y)};previous[i]=y}
     let phase=mode=="2d" ? planar.phase:renderer.phase
     if phase != "Final settling" {
      // Once inside the receiver, arrivals cannot tunnel below equal/heavier fluid.
      precondition(receiving.allSatisfy {$0.1>=floorY-0.10},"\(name) \(mode) crossed equal/heavier layer")
      if receiving.contains(where:{$0.1>topY+0.12 && $0.1<profile.height-0.10}) {seenCrossing=true}
      let landed=receiving.filter {$0.1<=topY+0.10}.count
      finalFraction=Float(landed)/Float(amount*(mode=="2d" ? LabFluid2D.particlesPerUnit:LabBoardRenderer.particlesPerUnit))
      if finalFraction>=0.94 {precleanupChecked=true}
     }
     let receivedFraction=Float(receiving.count)/Float(amount*(mode=="2d" ? LabFluid2D.particlesPerUnit:LabBoardRenderer.particlesPerUnit))
     let stage=receivedFraction>0.8 ? 2:(receivedFraction>0.4 ? 1:(receivedFraction>0.1 ? 0:-1))
     if stage>=0,captures.insert(stage).inserted {
      if mode=="2d" {try capture(LabFluid2DView(engine:planar),"\(name)-\(mode)-arrival\(stage)")} else {try capture3D(renderer,"\(name)-\(mode)-arrival\(stage)")}
     }
     if tick==140,mode=="3d" {
      let before=renderer.particleSamples();renderer.paused=true;renderer.advanceSimulation(deltaTime:1);precondition(renderer.particleSamples().map(\.position)==before.map(\.position));renderer.paused=false
     }
    }
    let final=mode=="2d" ? planar.game:renderer.game
    print("\(name) \(mode): committed=\(final.state==after) landed-before-cleanup=\(finalFraction) max-step=\(maxStep) crossing=\(seenCrossing)");fflush(stdout)
    precondition(final.pending==nil && final.state==after,"Pour failed or stuck")
    precondition(precleanupChecked,"Density layer only resolved at final cleanup")
    precondition(maxStep<0.40,"Visible particle teleported")
    if floor<residents.count {precondition(seenCrossing,"No visible descent through lighter fluid")}
    if mode=="2d" {try capture(LabFluid2DView(engine:planar),"\(name)-\(mode)-finished")} else {try capture3D(renderer,"\(name)-\(mode)-finished")}
   }
  }
  print("Density pour trajectories, stable ties, volume, pause and completion passed.")
  if CommandLine.arguments.contains("--routes") {
   for mode in [LabBoardPresentation.fluid2D,.fluid] {
    for puzzle in LabDiscipline.density.levels+LabDiscipline.crossover.levels {
     let session=FluidBoardSession(defaults:nil,device:device,library:library,restoredSave:LabComparisonSave(presentation:mode,pace:.quick,puzzle:puzzle),allowsConcurrentPours:true)
     let initial=session.state,route=puzzle.authoredRoute(from:initial)!
     for (index,operation) in route.enumerated() {
      switch operation {
      case .activate(let activation):session.activateApparatus(activation.apparatusID,animated:false)
      case .pour(let move):
       let expected=session.state.applying(move)!
       precondition(session.begin(move,automaticClock:false))
       for _ in 0..<1800 where session.busy {
        if mode == .fluid2D {session.advance2D(deltaTime:1/60)}
        else {session.renderer!.advanceSimulation(deltaTime:1/60)}
       }
       precondition(!session.busy && session.state==expected,"Route failed \(mode) \(puzzle) operation \(index): \(session.notice)")
      }
     }
     precondition(session.solved)
     let moves=session.moveCount
     for _ in 0..<moves {session.undo()}
     precondition(session.state==initial,"Undo did not restore route")
     print("Route \(mode.rawValue) \(puzzle.rawValue): \(route.count) operations, solved and undone");fflush(stdout)
    }
   }
  }
 }
}
