import SwiftUI
import AppKit
@main struct RenderCost {
 @MainActor static func main() throws {
  var engine=LabFluid2D(game:LabBoardGame(state:LabBoardPuzzle.greenArrival.initial));engine.quickMotion=true
  var rows:[[String:Any]]=[]
  let bitmap=CGContext(data:nil,width:1000,height:650,bitsPerComponent:8,bytesPerRow:4000,space:CGColorSpaceCreateDeviceRGB(),bitmapInfo:CGImageAlphaInfo.premultipliedLast.rawValue)!
  func render(_ updated:Bool)->Double {
   let start=ProcessInfo.processInfo.systemUptime
   if updated {
    let view=LabFluid2DView(engine:engine).frame(width:1000,height:650).background(Color.black)
    let image=ImageRenderer(content:view).cgImage!
    bitmap.draw(image,in:CGRect(x:0,y:0,width:1000,height:650))
    precondition(bitmap.data!.assumingMemoryBound(to:UInt8.self)[3]==255)
   } else {
    let view=LabFluid2DBaselineView(engine:engine).frame(width:1000,height:650).background(Color.black)
    let image=ImageRenderer(content:view).cgImage!
    bitmap.draw(image,in:CGRect(x:0,y:0,width:1000,height:650))
    precondition(bitmap.data!.assumingMemoryBound(to:UInt8.self)[3]==255)
   }
   return (ProcessInfo.processInfo.systemUptime-start)*1000
  }
  for scene in ["rest","impact"] {
   if scene=="impact" {
    _=engine.begin(engine.game.state.solution()!.first!)
    while engine.busy && engine.surfaces[1].energy<0.8 { engine.advance(deltaTime:1/120) }
   }
   for _ in 0..<6 { _=render(false);_=render(true) }
   var before:[Double]=[],after:[Double]=[]
   for index in 0..<40 {
    if index%2==0 { before.append(render(false));after.append(render(true)) }
    else { after.append(render(true));before.append(render(false)) }
   }
   before.sort();after.sort()
   rows.append(["scene":scene,"baselineMedianMs":before[20],"updatedMedianMs":after[20],"baselineP95Ms":before[38],"updatedP95Ms":after[38],"samplesPerVariant":40,"width":1000,"height":650])
  }
  let report:[String:Any]=["scope":"Mac offscreen ImageRenderer plus draw to a CPU bitmap; not on-device GPU cost or display presents","results":rows]
  let data=try JSONSerialization.data(withJSONObject:report,options:[.prettyPrinted,.sortedKeys])
  try data.write(to:URL(fileURLWithPath:CommandLine.arguments.dropFirst().first ?? "/private/tmp/vials-surface-render-cost.json"));print(String(data:data,encoding:.utf8)!)
 }
}
