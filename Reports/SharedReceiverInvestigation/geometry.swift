import Foundation
import simd
@main struct GeometryProbe {
 static func main() {
  let profiles=LabBoardLayout.profiles(count:4)
  let state=LabBoardState(layers:[[0],[0],[],[]])
  let a=state.move(from:0,to:2)!,b=state.move(from:1,to:2)!
  let pa=LabBoardLayout.vessels(profiles:profiles,move:a,time:2,tilt:1.2,cutoffTilt:nil,cutoffElapsed:0,returnElapsed:nil)[0]
  let pb=LabBoardLayout.vessels(profiles:profiles,move:b,time:2,tilt:1.2,cutoffTilt:nil,cutoffElapsed:0,returnElapsed:nil)[1]
  print("Existing same-side 3D source transforms coincide: \(pa.world==pb.world)")
  print("Source centers: \(pa.world.columns.3), \(pb.world.columns.3)")
 }
}
