import Foundation
import MetalKit
import SwiftUI
import AppKit
import simd

@main struct OverlapValidation {
 @MainActor static func main() async throws {
  let device=MTLCreateSystemDefaultDevice()!,library=try device.makeLibrary(URL:URL(fileURLWithPath:CommandLine.arguments[1]))
  let output=URL(fileURLWithPath:CommandLine.arguments[2]);try FileManager.default.createDirectory(at:output,withIntermediateDirectories:true)
  struct Fixture {let name:String;let layers:[[Int]];let a:(Int,Int);let b:(Int,Int);let delay:Int}
  let fixtures=[
   Fixture(name:"near-full",layers:[[0,0,0],[0,0,0],[],[],[1],[2]],a:(0,2),b:(1,2),delay:0),
   Fixture(name:"crossing",layers:[[2,0,0],[],[1],[],[2,1,1],[]],a:(0,5),b:(4,1),delay:40),
   Fixture(name:"shared-left",layers:[[],[1],[],[2],[1,0,0],[2,0,0]],a:(4,0),b:(5,0),delay:90),
   Fixture(name:"shared-right",layers:[[2,0,0],[1,0,0],[1],[],[2],[]],a:(0,5),b:(1,5),delay:0),
   Fixture(name:"return-crossing",layers:[[2,0],[],[1],[],[2,1,1],[]],a:(0,5),b:(4,1),delay:140)
  ]
  func penetration(_ a:LabVesselUniform,_ b:LabVesselUniform,_ ap:LabVesselProfile,_ bp:LabVesselProfile)->Float {
   // Sample the actual outer profile. This catches intersections; it does not
   // claim a mathematical collision proof for arbitrary continuous motion.
   let transform=b.inverseWorld*a.world
   var deepest:Float=0
   for level in 0...20 {
    let y=ap.height*Float(level)/20,r=ap.radius(at:y)+0.035
    for ring in 0..<16 {
     let angle=Float(ring)*2*Float.pi/16,q=(transform*SIMD4(r*cos(angle),y,r*sin(angle),1)).xyz
     if q.y>0 && q.y<bp.height {deepest=max(deepest,min(min(q.y,bp.height-q.y),bp.radius(at:q.y)+0.035-length(SIMD2(q.x,q.z))))}
    }
   }
   return deepest
  }
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
    let content:AnyView=mode == .classic ? AnyView(LabClassicBoardView(state:session.state,pour:nil,additionalPours:session.concurrentClassicPours)):AnyView(LabPlanarSurface(display:session.planarDisplay))
    cg=ImageRenderer(content:content.frame(width:CGFloat(width),height:CGFloat(height)).background(Color(red:0.026,green:0.043,blue:0.06))).cgImage!
   }
   try NSBitmapImageRep(cgImage:cg).representation(using:.png,properties:[:])!.write(to:output.appendingPathComponent(name+".png"))
  }
  var rows:[[String:Any]]=[]
  for mode in LabBoardPresentation.allCases {
   for fixture in fixtures {
    let initial=LabBoardState(layers:fixture.layers)
    let save=LabComparisonSave(presentation:mode,pace:.quick,puzzle:.firstSort,games:["firstSort":LabBoardGame(state:initial)])
    let session=FluidBoardSession(defaults:nil,device:device,library:library,restoredSave:save,allowsConcurrentPours:true)
    var maxPenetration:Float=0,penetratingFrames=0,clippedFrames=0,spatialClippedFrames=0,joined=false
    precondition(session.begin(session.availableMove(from:fixture.a.0,to:fixture.a.1)!,automaticClock:false))
    for tick in 0..<1500 {
     if tick==fixture.delay {precondition(session.begin(session.availableMove(from:fixture.b.0,to:fixture.b.1)!,automaticClock:false));joined=true}
     await session.advanceConcurrent(deltaTime:1/60)
     let moving=Set(session.pourQueue.active.map {$0.move.source})
     if mode == .fluid,tick%3==0 {
      let renderer=session.renderer!,vessels=renderer.currentVessels
      var depth:Float=0
      for a in moving {for b in vessels.indices where b != a {
       depth=max(depth,penetration(vessels[a],vessels[b],renderer.profiles[a],renderer.profiles[b]))
       depth=max(depth,penetration(vessels[b],vessels[a],renderer.profiles[b],renderer.profiles[a]))
      }}
      maxPenetration=max(maxPenetration,depth);if depth>0.025 {penetratingFrames+=1}
      var clipped=false
      for aspect:Float in [0.6,1.667] {for orbit:Float in [-0.35,0.12,0.35] {
       let camera=LabBoardLayout.camera(aspect:aspect,azimuth:orbit,vesselCount:vessels.count).0
       for a in moving {let profile=renderer.profiles[a]
        for level in 0...12 {for ring in 0..<12 {
         let y=profile.height*Float(level)/12,r=profile.radius(at:y)+0.035,angle=Float(ring)*2*Float.pi/12
         let p=camera*vessels[a].world*SIMD4(r*cos(angle),y,r*sin(angle),1)
         if abs(p.x)>p.w*0.99 || abs(p.y)>p.w*0.99 {clipped=true}
        }}
       }
      }}
      if clipped {spatialClippedFrames+=1}
     }
     if mode == .fluid2D {
      let engine=session.fluid2D,layout=LabClassicLayout(size:CGSize(width:600,height:1000),vesselCount:6)
      var clipped=false
      for source in moving {
       let pose=engine.pose(source),profile=engine.profiles[source]
       for level in 0...16 {for side:Float in [-1,1] {
        let y=profile.height*Float(level)/16,world=pose.world(SIMD2(side*profile.radius(y),y)),x=300+CGFloat(world.x)*layout.scale
        if x<3 || x>597 {clipped=true}
       }}
      }
      if clipped {clippedFrames+=1}
     }
     if [65,140,220].contains(tick) {
      let stem="\(mode.rawValue)-\(fixture.name)-\(tick)"
      try capture(session,mode,stem+"-landscape",1000,600)
      try capture(session,mode,stem+"-portrait",600,1000)
      if mode == .fluid,tick==140 {for orbit:Float in [-0.35,0.35] {try capture(session,mode,stem+"-orbit-\(orbit)",1000,600,orbit)}}
     }
     if joined && !session.busy {break}
    }
    precondition(joined && !session.busy && session.moveCount==2,"Rejected or stuck \(mode) \(fixture.name): \(session.notice)")
    rows.append(["mode":mode.rawValue,"fixture":fixture.name,"completed":session.moveCount,"maximumPenetration":maxPenetration,"penetratingFrames":penetratingFrames,"planarClippedFrames":clippedFrames,"spatialClippedFrames":spatialClippedFrames])
    print("\(mode.rawValue) \(fixture.name) penetration=\(maxPenetration) clipped=\(clippedFrames) spatialClipped=\(spatialClippedFrames)");fflush(stdout)
   }
  }
  precondition(rows.allSatisfy {($0["penetratingFrames"] as! Int)==0 && ($0["planarClippedFrames"] as! Int)==0 && ($0["spatialClippedFrames"] as! Int)==0},"Overlap or clipping regression")
  try JSONSerialization.data(withJSONObject:rows,options:[.prettyPrinted,.sortedKeys]).write(to:output.appendingPathComponent("overlap-summary.json"))
 }
}
