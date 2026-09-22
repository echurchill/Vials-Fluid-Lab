import Foundation
import Metal
import simd

@main @MainActor struct ReturnedSourceValidation {
 static func check(_ ok:Bool,_ message:String) {if !ok {fatalError(message)}}
 static func main() async throws {
  let device=MTLCreateSystemDefaultDevice()!
  let library=try device.makeLibrary(URL:URL(fileURLWithPath:CommandLine.arguments[1]))
  for mode in LabBoardPresentation.allCases where ProcessInfo.processInfo.environment["LAB_TEST_MODE"].map({$0==mode.rawValue}) ?? true {
  for pace in [LabBoardPace.quick,.relaxed] {
   for offset in [-15,0,15,45] {
   let initial=LabBoardPuzzle.buriedClue.initial
   let s=FluidBoardSession(defaults:nil,device:device,library:library,restoredSave:.init(presentation:mode,pace:pace,puzzle:.buriedClue),allowsConcurrentPours:true)
   var expected=initial
   func begin(_ from:Int,_ to:Int) {
    guard let move=s.availableMove(from:from,to:to) else {fatalError("Unavailable \(from) → \(to)")}
    check(s.begin(move,automaticClock:false),"Rejected pour")
    expected=expected.applyingReserved(move)!
   }
   begin(1,3)
   // B gets a head start, then returns while A is still active.
   let lead=(pace == .quick ? 60:96)+offset
   for _ in 0..<lead {await s.advanceConcurrent(deltaTime:1/60)}
   begin(0,2)
   for _ in 0..<2400 where !s.canTap(1) {await s.advanceConcurrent(deltaTime:1/60)}
   check(s.pourQueue.items.contains {$0.move.source==0},"Fixture lost A overlap")
   begin(1,2)
   let home=LabBoardLayout.homes(count:4)[0]
   var homeWhileOther=false,staleFrames=0,reused=false
   for _ in 0..<2400 where s.busy {
    await s.advanceConcurrent(deltaTime:1/60)
    let homePose:Bool
    switch mode {
    case .fluid:
     let a=s.renderer!.currentVessels[0].world
     homePose=simd_distance(a.columns.3.xyz,home)<0.001 && abs(a.columns.1.y-1)<0.001
    case .fluid2D:
     let a=s.fluid2D.pose(0)
     homePose=simd_distance(a.base,s.fluid2D.home(0))<0.001 && abs(a.angle)<0.001
    case .classic:
     // The rendered lowering phase ends at 6.75 + 0.45 seconds.
     homePose=s.concurrentClassicPours.first {$0.move.source==0}.map {$0.time>=7.2} ?? true
    }
    let aActive=s.pourQueue.items.contains {$0.move.source==0}
    let bActive=s.pourQueue.items.contains {$0.move.source==1}
    if homePose && bActive && !reused {
     homeWhileOther=true
     staleFrames=aActive ? staleFrames+1:0
     check(staleFrames<=3,"\(mode) \(pace): A is home but still marked Pouring while B continues")
     if let move=s.availableMove(from:0,to:3) {
      check(s.canTap(0),"Returned A cannot be selected")
      check(s.begin(move,automaticClock:false),"Returned A cannot pour again")
      expected=expected.applyingReserved(move)!;reused=true
     }
    }
   }
   check(homeWhileOther && reused,"\(mode) \(pace): A was not reusable before B finished")
   check(!s.busy && s.moveCount==4 && s.state.stacks==expected.stacks,"Lost or duplicate commit")
   if mode == .fluid {
   let samples=s.renderer!.particleSamples()
   check(samples.count==initial.colors.count*LabBoardRenderer.particlesPerUnit,"Particle count changed")
   for (owner,stack) in s.state.stacks.enumerated() {
    for parcel in stack {
     check(samples.filter {Int($0.visual.y)==parcel && Int($0.position.w)==owner}.count==LabBoardRenderer.particlesPerUnit,"Parcel ownership corrupted after reuse")
    }
   }
   } else if mode == .fluid2D {
    let samples=s.fluid2D.particles
    check(samples.count==initial.colors.count*LabFluid2D.particlesPerUnit,"Particle count changed")
    for (owner,stack) in s.state.stacks.enumerated() {
     for parcel in stack {
      check(samples.filter {$0.parcel==parcel && $0.owner==owner}.count==LabFluid2D.particlesPerUnit,"2D parcel ownership corrupted after reuse")
     }
    }
   }
   let saved=try JSONDecoder().decode(LabComparisonSave.self,from:s.checkpointData())
   check(saved.games[LabBoardPuzzle.buriedClue.rawValue]!.state==s.state,"Checkpoint differs")
   for _ in 0..<4 {s.undo()}
   check(s.state.stacks==initial.stacks,"Undo did not restore board")
   print("PASS \(mode) \(pace) lead=\(lead): B→D, A→C, B→C, returned A→D; independent release, particles, save and Undo");fflush(stdout)
   }
  }
  }
 }
}
