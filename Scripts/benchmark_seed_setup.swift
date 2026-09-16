import Foundation
import MetalKit
@main struct SeedBenchmark {
 @MainActor static func main() throws {
  let device=MTLCreateSystemDefaultDevice()!,lib=try device.makeLibrary(URL:URL(fileURLWithPath:CommandLine.arguments[1]))
  let old=try BaselineBoardRenderer(device:device,library:lib),new=try LabBoardRenderer(device:device,library:lib)
  let game=LabBoardGame(state:LabBoardPuzzle.greenArrival.initial)
  old.install(game:game);new.install(game:game)
  let canonical=old.particleSamples()
  func compare() {
   let samples=new.particleSamples(),expected=old.particleSamples();precondition(samples.count==expected.count)
   precondition(zip(samples,expected).allSatisfy {$0.position==$1.position && $0.predicted==$1.predicted && $0.velocity==$1.velocity && $0.visual==$1.visual},"Cached particle seeds changed")
  }
  compare()
  func baseline()->Double {let start=ProcessInfo.processInfo.systemUptime;old.installSimulation(game:game,samples:canonical,vessels:[0,1]);return (ProcessInfo.processInfo.systemUptime-start)*1000}
  func candidate()->Double {let start=ProcessInfo.processInfo.systemUptime;new.installSimulation(game:game,samples:canonical,vessels:[0,1]);return (ProcessInfo.processInfo.systemUptime-start)*1000}
  for _ in 0..<4 {_=baseline();_=candidate()}
  var before:[Double]=[],after:[Double]=[]
  for i in 0..<60 {if i%2==0 {before.append(baseline());after.append(candidate())} else {after.append(candidate());before.append(baseline())};compare()}
  // Changing between four and six profiles must invalidate canonical geometry.
  new.install(game:LabBoardGame());new.install(game:game);old.install(game:game);compare()
  func summary(_ values:[Double])->[String:Any] {let s=values.sorted();return ["samples":s.count,"median":s[s.count/2],"p95":s[Int(Double(s.count)*0.95)],"maximum":s.last!]}
  let result:[String:Any]=["scope":"Alternating same-process Mac receiver-group initialization; canonical particles verified bit-for-bit, including profile-count changes. Excludes fluid advancement and rendering.","baselineMs":summary(before),"cachedMs":summary(after)]
  try JSONSerialization.data(withJSONObject:result,options:[.prettyPrinted,.sortedKeys]).write(to:URL(fileURLWithPath:CommandLine.arguments[2]));print(result)
 }
}
