import SwiftUI
import MetalKit

@main struct PourComparisonValidation {
    @MainActor static func main() async throws {
        let args=CommandLine.arguments
        func option(_ key:String)->String { args[args.firstIndex(of:key)!+1] }
        let output=URL(fileURLWithPath:option("--output"))
        try FileManager.default.createDirectory(at:output,withIntermediateDirectories:true)
        let device=MTLCreateSystemDefaultDevice()!,library=try device.makeLibrary(URL:URL(fileURLWithPath:option("--library")))
        func check(_ value:Bool,_ message:String) { precondition(value,message) }
        let session=FluidBoardSession(defaults:nil,device:device,library:library)
        session.changePuzzle(.greenArrival);session.changePresentation(.fluid2D);session.changePace(.quick)
        let before=try session.checkpointData(),state=session.state
        check(session.canComparePour,"Initial comparison availability")
        session.select(1);check(session.rejectedVial==1 && session.selected==nil,"Empty source should be rejected")
        session.select(0);check(session.selected==0 && session.rejectedVial==nil,"New source clears rejection")
        check(session.validDestinations==Set([1,3,5]),"Legal destinations should reflect the actual rules")
        session.select(2);check(session.rejectedVial==2 && session.selected==0 && session.state==state,"Invalid target changed the source or board")
        session.select(0);check(session.selected==nil && session.rejectedVial==nil,"Deselect should clear feedback")
        session.hint();check(session.validDestinations.contains(session.hintTarget!),"Hint was not legal")
        let move=state.solution()!.first!
        check(session.begin(move,automaticClock:false),"Begin played pour")
        check(!session.canComparePour,"Comparison available during pour")
        for _ in 0..<900 where session.busy { session.advance2D(deltaTime:1/60) }
        check(session.lastPour?.state==state && session.lastPour?.move==move,"Last pour did not capture the starting board")
        let committed=session.state,history=session.game.history
        let comparison=LabPourComparison(example:session.comparisonExample!,device:device,library:library)
        await comparison.prepare()
        check(comparison.durations.count==3,"All modes should prepare")
        let descriptor=MTLTextureDescriptor.texture2DDescriptor(pixelFormat:.bgra8Unorm_srgb,width:600,height:390,mipmapped:false)
        descriptor.usage=[.renderTarget,.shaderRead];descriptor.storageMode = .shared
        let target=device.makeTexture(descriptor:descriptor)!
        var rows:[[String:Any]]=[]
        for mode in LabBoardPresentation.allCases {
            comparison.choose(mode)
            check(comparison.session.state==state,"Mode switch should restore the exact starting board")
            check(comparison.play(automaticClock:false),"Replay begin")
            comparison.choose(mode == .classic ? .fluid2D:.classic)
            check(comparison.session.presentation==mode,"Busy switch changed playback")
            var frames=0
            while comparison.session.busy && frames<900 {
                let s=comparison.session
                if mode == .classic { s.advanceClassic(deltaTime:1/60) }
                else if mode == .fluid2D { s.advance2D(deltaTime:1/60) }
                else { await s.renderer!.encodeFrame(target:target,deltaTime:1/60).completed() }
                frames+=1
            }
            let seconds=Double(frames)/60
            check(comparison.session.state==state.applying(move),"Replay result differed")
            check(abs(seconds-5)<0.20,"Matched duration differed by more than 0.20 seconds")
            check(session.state==committed && session.game.history==history,"Preview altered gameplay")
            rows.append(["presentation":mode.rawValue,"matchedSeconds":seconds,"preparedSimulationSeconds":comparison.durations[mode]!,"committed":true])
        }
        comparison.choose(.fluid2D);check(comparison.play(),"Async preview start")
        try await Task.sleep(for:.milliseconds(100))
        comparison.session.togglePause();let paused=comparison.session.fluid2D
        try await Task.sleep(for:.milliseconds(100))
        check(comparison.session.fluid2D.particles==paused.particles,"Preview pause moved particles")
        weak var discarded=comparison.session
        comparison.stop();try await Task.sleep(for:.milliseconds(100))
        check(discarded==nil,"Stopped preview retained its worker session")
        check(!comparison.session.busy && comparison.session.state==state,"Stop did not restore preview")
        comparison.matchDuration=false;check(comparison.play(automaticClock:false),"Normal pace replay")
        check(comparison.session.effectiveSpeed==LabBoardPace.quick.speed,"Normal pace was modified")
        comparison.stop()
        session.undo();check(session.state==state && session.lastPour==nil,"Undo retained stale replay")
        let checkpoint=try JSONDecoder().decode(LabComparisonSave.self,from:session.checkpointData())
        let original=try JSONDecoder().decode(LabComparisonSave.self,from:before)
        check(checkpoint.games[session.puzzle.rawValue]?.state==original.games[session.puzzle.rawValue]?.state,"Preview changed saved board")
        for fixture in [LabBoardState(layers:[[0,1,1,1],[],[1,0,0,0],[]]),LabBoardState(layers:[[0,0],[0,0],[1,1,1,1],[]])] {
            let transfer=fixture.move(from:0,to:1)!
            let sample=LabPourComparison(example:LabPourExample(puzzle:.firstSort,state:fixture,move:transfer),device:device,library:library)
            await sample.prepare();check(sample.durations.count==3,"Stress fixture preparation")
            for mode in LabBoardPresentation.allCases {
                sample.choose(mode);check(sample.play(automaticClock:false),"Stress replay begin")
                var frames=0
                while sample.session.busy && frames<900 {
                    if mode == .classic { sample.session.advanceClassic(deltaTime:1/60) }
                    else if mode == .fluid2D { sample.session.advance2D(deltaTime:1/60) }
                    else { await sample.session.renderer!.encodeFrame(target:target,deltaTime:1/60).completed() }
                    frames+=1
                }
                let seconds=Double(frames)/60
                check(sample.session.state==fixture.applying(transfer) && abs(seconds-5)<0.2,"Stress replay result or duration")
                rows.append(["presentation":mode.rawValue,"units":transfer.amount,"matchedSeconds":seconds,"preparedSimulationSeconds":sample.durations[mode]!,"committed":true])
            }
            sample.session.discardPreview()
        }
        let fallback=LabPourComparison(example:comparison.example,device:nil)
        await fallback.prepare();check(fallback.durations[.fluid]==nil && fallback.durations[.fluid2D] != nil,"No-Metal fallback")
        fallback.choose(.classic);check(fallback.session.presentation == .classic,"Fallback Classic unavailable")
        let solved=FluidBoardSession(defaults:nil,device:nil,restoredSave:LabComparisonSave(presentation:.classic,games:[LabBoardPuzzle.firstSort.rawValue:LabBoardGame(state:LabBoardState(layers:[[0,0,0,0],[],[1,1,1,1],[]]))]))
        check(solved.vialComplete(0) && !solved.vialComplete(1),"Completion cue confused empty and sorted vials")
        try JSONSerialization.data(withJSONObject:rows,options:[.prettyPrinted,.sortedKeys]).write(to:output.appendingPathComponent("comparison.json"))
        print("PASS: exact replay across all three modes, matched duration, busy guards, stop/pause, normal pace, feedback, saved game isolation and no-Metal fallback")
    }
}
