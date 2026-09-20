import Foundation
import MetalKit
import SwiftUI
import AppKit

/// Fixed render fixtures for judging density glyphs; not a performance benchmark.
@main struct DensityPatternPreview {
 @MainActor static func main() throws {
  let device=MTLCreateSystemDefaultDevice()!,library=try device.makeLibrary(URL:URL(fileURLWithPath:CommandLine.arguments[1]))
  let output=URL(fileURLWithPath:CommandLine.arguments[2]);try FileManager.default.createDirectory(at:output,withIntermediateDirectories:true)
  let pigments=[0,1,2,8,9,4]
  let layers=LabBoardState(layers:pigments.map {Array(repeating:$0,count:3)},capacities:Array(repeating:3,count:6),densityLayers:Array(repeating:[.heavy,.medium,.light],count:6),behavior:.density)
  let thin=LabBoardState(layers:(0..<10).map {Array(repeating:pigments[$0%6],count:6)},capacities:Array(repeating:6,count:10),densityLayers:Array(repeating:[.heavy,.heavy,.medium,.medium,.light,.light],count:10),behavior:.density)
  let small=LabBoardState(layers:[[0],[0],[0],[1],[1],[1]],capacities:Array(repeating:1,count:6),densityLayers:[[.light],[.medium],[.heavy],[.light],[.medium],[.heavy]],behavior:.density)
  for (name,state,width,height) in [("layers",layers,1000,600),("wide",thin,1000,600),("small",small,760,500),("portrait",layers,600,900)] {
   for mode in LabBoardPresentation.allCases {
    let cg:CGImage
    if mode == .fluid {
     let renderer=try LabBoardRenderer(device:device,library:library);renderer.install(game:LabBoardGame(state:state));renderer.paused=true
     let d=MTLTextureDescriptor.texture2DDescriptor(pixelFormat:.bgra8Unorm_srgb,width:width,height:height,mipmapped:false);d.usage=[.renderTarget,.shaderRead];d.storageMode = .shared
     let t=device.makeTexture(descriptor:d)!,command=renderer.encodeFrame(target:t,deltaTime:0)
     command.waitUntilCompleted();precondition(command.status == .completed,"Metal render failed: \(String(describing:command.error))")
     let bitmap=NSBitmapImageRep(bitmapDataPlanes:nil,pixelsWide:width,pixelsHigh:height,bitsPerSample:8,samplesPerPixel:4,hasAlpha:true,isPlanar:false,colorSpaceName:.deviceRGB,bitmapFormat:[],bytesPerRow:width*4,bitsPerPixel:32)!
     t.getBytes(bitmap.bitmapData!,bytesPerRow:width*4,from:MTLRegionMake2D(0,0,width,height),mipmapLevel:0)
     for i in stride(from:0,to:width*height*4,by:4) {let b=bitmap.bitmapData![i];bitmap.bitmapData![i]=bitmap.bitmapData![i+2];bitmap.bitmapData![i+2]=b};cg=bitmap.cgImage!
    } else {
     let view:AnyView=mode == .classic ? AnyView(LabClassicBoardView(state:state,pour:nil)):AnyView(LabFluid2DView(engine:LabFluid2D(game:LabBoardGame(state:state))))
     cg=ImageRenderer(content:view.frame(width:CGFloat(width),height:CGFloat(height)).background(Color(red:0.026,green:0.043,blue:0.06))).cgImage!
    }
    try NSBitmapImageRep(cgImage:cg).representation(using:.png,properties:[:])!.write(to:output.appendingPathComponent("\(name)-\(mode.rawValue).png"))
    print("PASS \(name) \(mode.rawValue)")
   }
  }
 }
}
