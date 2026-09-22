import SwiftUI
import AppKit
@main @MainActor struct PreviewJourney {
 static func main() throws {
  for (name,width) in [("journey-wide",1000),("journey-compact",650)] {
   let view=LabJourneyMapView(current:.warmBlend,completed:[.firstSort,.crossCurrents,.heavyLanding],choose:{_ in},close:{})
    .mapContent(wide:width>=800).frame(width:CGFloat(width)).background(Color(red:0.026,green:0.043,blue:0.060)).foregroundStyle(Color(red:0.80,green:0.88,blue:0.90)).environment(\.colorScheme,.dark)
   let renderer=ImageRenderer(content:view);renderer.scale=1
   guard let image=renderer.cgImage else {fatalError("Map failed to render")}
   try NSBitmapImageRep(cgImage:image).representation(using:.png,properties:[:])!.write(to:URL(fileURLWithPath:CommandLine.arguments[1]).appendingPathComponent(name+".png"))
  }
 }
}
