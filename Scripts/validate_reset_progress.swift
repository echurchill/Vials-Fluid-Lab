import Foundation
import MetalKit

@main struct ResetProgressValidation {
 @MainActor static func main() async throws {
  let device=MTLCreateSystemDefaultDevice()!,library=try device.makeLibrary(URL:URL(fileURLWithPath:CommandLine.arguments[1]))
  let domain="dev.vials.reset-test.\(UUID().uuidString)",defaults=UserDefaults(suiteName:domain)!
  defer {defaults.removePersistentDomain(forName:domain)}
  var solved=LabBoardGame()
  for move in solved.state.solution()! {precondition(solved.begin(from:move.source,to:move.destination) != nil);precondition(solved.commit(move))}
  precondition(solved.state.solved)
  let originalKeys=["progress.mode","progress.levelNumber","progress.zenSalt","player.levelResults","player.flowState","vials.levelGenerationVariants","tester.levelFeedback"]
  for mode in LabBoardPresentation.allCases {
   let save=LabComparisonSave(presentation:mode,pace:.quick,puzzle:.greenArrival,games:["firstSort":solved,"confluence":LabBoardGame(state:LabBoardPuzzle.confluence.initial)])
   defaults.set(try JSONEncoder().encode(save),forKey:"lab.comparison.v1")
   defaults.set(true,forKey:"lab.sound");defaults.set(false,forKey:"lab.haptics");defaults.set("lowEnergy",forKey:"lab.quality")
   defaults.set("keep me",forKey:"unrelated.preference")
   for key in originalKeys {defaults.set("old progress",forKey:key)}
   let session=FluidBoardSession(defaults:defaults,device:device,library:library,allowsConcurrentPours:true)
   // Two sources into one receiver, with a worker update allowed to be in flight.
   precondition(session.begin(session.availableMove(from:0,to:1)!,automaticClock:false))
   precondition(session.begin(session.availableMove(from:4,to:1)!,automaticClock:false))
   let inFlight=Task { await session.advanceConcurrent(deltaTime:1/60) }
   await Task.yield()
   session.setSuspended(true)
   let oldGeneration=GameProgressStore.resetGeneration
   session.resetAllProgress();GameProgressStore.resetAll(defaults:defaults)
   precondition(oldGeneration != GameProgressStore.resetGeneration)
   session.setSuspended(false)
   await inFlight.value
   try? await Task.sleep(for:.milliseconds(80))
   precondition(!session.busy && session.activeMoves.isEmpty && !session.paused)
   precondition(session.state == LabBoardPuzzle.firstSort.initial && session.puzzle == .firstSort && session.moveCount==0)
   precondition(session.completedPuzzleCount==0 && LabBoardPuzzle.allCases.allSatisfy {!session.hasCompleted($0)})
   precondition(session.presentation == .fluid && session.pace == .relaxed && session.lastPour == nil)
   precondition(session.soundEnabled && !session.hapticsEnabled && session.quality == .lowEnergy)
   session.undo();precondition(session.state == LabBoardPuzzle.firstSort.initial && session.moveCount==0)
   let checkpoint=try JSONDecoder().decode(LabComparisonSave.self,from:session.checkpointData())
   precondition(checkpoint.games.keys.sorted()==["firstSort"])
   precondition(originalKeys.allSatisfy {defaults.object(forKey:$0)==nil})
   precondition(defaults.string(forKey:"unrelated.preference")=="keep me")
   let original=GameProgressStore.load(defaults:defaults)
   precondition(original.mode == .easy && original.levelNumber==1)
   let reloaded=FluidBoardSession(defaults:defaults,device:device,library:library,allowsConcurrentPours:true)
   precondition(reloaded.puzzle == .firstSort && reloaded.completedPuzzleCount==0 && reloaded.moveCount==0)
   for puzzle in LabBoardPuzzle.allCases {reloaded.changePuzzle(puzzle);precondition(reloaded.state == puzzle.initial && reloaded.moveCount==0 && !reloaded.hasCompleted(puzzle))}
   reloaded.resetAllProgress();precondition(reloaded.puzzle == .firstSort && reloaded.completedPuzzleCount==0)
   print("\(mode.rawValue): active-pour reset, all levels, undo isolation, relaunch, Original game stores and preserved preferences passed")
  }
 }
}
