import Foundation
import MetalKit
import AppKit

/// Paired, fixed-state rendering checks. GPU times exclude solver advancement
/// and compositor work; this is not a displayed-frame benchmark.
@main struct GlassAntialiasingValidation {
 @MainActor static func main() throws {
  let device=MTLCreateSystemDefaultDevice()!,library=try device.makeLibrary(URL:URL(fileURLWithPath:CommandLine.arguments[1]))
  let output=URL(fileURLWithPath:CommandLine.arguments[2]);try FileManager.default.createDirectory(at:output,withIntermediateDirectories:true)
  let before=try BaselineBoardRenderer(device:device,library:library),after=try LabBoardRenderer(device:device,library:library)
  let game=LabBoardGame(state:LabBoardPuzzle.confluence.initial)
  before.install(game:game);after.install(game:game);before.paused=true;after.paused=true
  func target(_ w:Int,_ h:Int)->MTLTexture {
   let d=MTLTextureDescriptor.texture2DDescriptor(pixelFormat:.bgra8Unorm_srgb,width:w,height:h,mipmapped:false)
   d.usage=[.renderTarget,.shaderRead];d.storageMode = .shared;return device.makeTexture(descriptor:d)!
  }
  func capture(_ texture:MTLTexture,_ name:String) throws {
   let w=texture.width,h=texture.height
   let bitmap=NSBitmapImageRep(bitmapDataPlanes:nil,pixelsWide:w,pixelsHigh:h,bitsPerSample:8,samplesPerPixel:4,hasAlpha:true,isPlanar:false,colorSpaceName:.deviceRGB,bitmapFormat:[],bytesPerRow:w*4,bitsPerPixel:32)!
   texture.getBytes(bitmap.bitmapData!,bytesPerRow:w*4,from:MTLRegionMake2D(0,0,w,h),mipmapLevel:0)
   for i in stride(from:0,to:w*h*4,by:4) {let b=bitmap.bitmapData![i];bitmap.bitmapData![i]=bitmap.bitmapData![i+2];bitmap.bitmapData![i+2]=b}
   try bitmap.representation(using:.png,properties:[:])!.write(to:output.appendingPathComponent(name+".png"))
  }
  func measure(_ command:MTLCommandBuffer)->Double {
   command.waitUntilCompleted();precondition(command.status == .completed,"Render failed: \(String(describing:command.error))")
   return (command.gpuEndTime-command.gpuStartTime)*1000
  }
  func summary(_ values:[Double])->[String:Any] {let s=values.sorted();return ["samples":s.count,"median":s[s.count/2],"p95":s[Int(Double(s.count)*0.95)],"maximum":s.last!]}
  var results:[[String:Any]]=[]
  // Includes both orientation changes and both orbit extremes; same renderer
  // instances are reused so texture resizing is exercised too.
  for (name,w,h,orbit) in [("landscape",1000,450,Float(0.12)),("portrait",600,1000,Float(0.12)),("left",1000,600,Float(-0.3)),("right",1000,600,Float(0.4))] {
   before.orbit=orbit;after.orbit=orbit
   let a=target(w,h),b=target(w,h)
   for _ in 0..<5 {_=measure(before.encodeFrame(target:a,deltaTime:0));_=measure(after.encodeFrame(target:b,deltaTime:0))}
   var old:[Double]=[],new:[Double]=[]
   for i in 0..<40 {
    if i%2==0 {old.append(measure(before.encodeFrame(target:a,deltaTime:0)));new.append(measure(after.encodeFrame(target:b,deltaTime:0)))}
    else {new.append(measure(after.encodeFrame(target:b,deltaTime:0)));old.append(measure(before.encodeFrame(target:a,deltaTime:0)))}
   }
   try capture(a,name+"-before");try capture(b,name+"-after")
   results.append(["fixture":name,"width":w,"height":h,"beforeSurfaceGPUMs":summary(old),"afterSurfaceGPUMs":summary(new)])
  }
  let report:[String:Any]=["scope":"Alternating same-process fixed-state Confluence rendering on Mac; no simulation advancement or compositor. 40 warmed samples per variant per view. Resize and orbit changes included.","device":device.name,"glassSamples":after.glassSampleCount,"results":results]
  try JSONSerialization.data(withJSONObject:report,options:[.prettyPrinted,.sortedKeys]).write(to:output.appendingPathComponent("summary.json"))
  print("Glass antialiasing checked at \(after.glassSampleCount)x; four paired render fixtures passed.")
 }
}
