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
  for mode in LabBoardPresentation.allCases {
   for puzzle in [LabBoardPuzzle.measuredBatch,.heavyLanding,.fiveStreams] {
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
       if mode == .classic {session.advanceClassic(deltaTime:1/60)}
       else if mode == .fluid2D {session.advance2D(deltaTime:1/60)}
       else {
        let command=session.renderer!.encodeFrame(target:texture,deltaTime:1/60)
        finish(command)
       }
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
