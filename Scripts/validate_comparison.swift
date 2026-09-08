import SwiftUI
import MetalKit
import AppKit

@main struct ComparisonValidation {
    @MainActor static func main() throws {
        let args=CommandLine.arguments
        func option(_ name:String,_ fallback:String) -> String { guard let i=args.firstIndex(of:name),i+1<args.count else { return fallback };return args[i+1] }
        let output=URL(fileURLWithPath:option("--output","/tmp/vials-comparison"))
        try FileManager.default.createDirectory(at:output,withIntermediateDirectories:true)
        let device=MTLCreateSystemDefaultDevice()!,lib=try device.makeLibrary(URL:URL(fileURLWithPath:option("--library","default.metallib")))
        let descriptor=MTLTextureDescriptor.texture2DDescriptor(pixelFormat:.bgra8Unorm_srgb,width:1000,height:650,mipmapped:false)
        descriptor.storageMode = .shared;descriptor.usage=[.renderTarget,.shaderRead]
        let texture=device.makeTexture(descriptor:descriptor)!
        var errors:[String]=[],results:[[String:Any]]=[]
        for puzzle in LabBoardPuzzle.allCases { for pace in LabBoardPace.allCases {
            let session=FluidBoardSession(defaults:nil,device:device,library:lib)
            session.changePuzzle(puzzle);session.changePace(pace)
            guard let route=session.state.solution() else { errors.append("Unsolvable puzzle: \(puzzle)");continue }
            let original=session.state
            let stableIDs=original.colors
            var states:[LabBoardState]=[]
            for (index,move) in route.enumerated() {
                let mode:LabBoardPresentation=index%2 == 0 ? .classic:.fluid
                session.changePresentation(mode)
                let before=session.state, count=session.moveCount
                states.append(before)
                session.changePresentation(mode == .classic ? .fluid:.classic)
                session.changePresentation(mode)
                if session.state != before || session.moveCount != count { errors.append("Switch changed the game") }
                if mode == .fluid {
                    let particles=session.renderer!.particleSamples()
                    session.changePresentation(.classic);session.changePresentation(.fluid)
                    if zip(particles,session.renderer!.particleSamples()).contains(where: { $0.position != $1.position || $0.visual != $1.visual }) { errors.append("Switch lost the settled particle snapshot") }
                }
                guard session.begin(move,automaticClock:false) else { errors.append("Move refused");break }
                session.changePresentation(mode == .classic ? .fluid:.classic)
                session.changePace(pace == .quick ? .relaxed:.quick)
                session.changePuzzle(puzzle == .firstSort ? .lastDrops:.firstSort)
                session.undo()
                if session.presentation != mode || session.pace != pace || session.puzzle != puzzle || !session.busy { errors.append("Busy controls changed a pending transaction") }
                let beforePause=session.classicPour?.time ?? session.renderer!.simulationTime
                session.togglePause()
                if mode == .classic { session.advanceClassic(deltaTime:1) }
                else { session.renderer!.encodeFrame(target:texture,deltaTime:1).waitUntilCompleted() }
                let afterPause=session.classicPour?.time ?? session.renderer!.simulationTime
                if beforePause != afterPause { errors.append("Pause advanced animation") }
                session.togglePause()
                var duration:Float=0
                for frame in 0..<900 {
                    duration=Float(frame+1)/60
                    if mode == .classic { session.advanceClassic(deltaTime:1/60) }
                    else { session.renderer!.encodeFrame(target:texture,deltaTime:1/60).waitUntilCompleted() }
                    if !session.busy { break }
                }
                if session.state != before.applying(move) || session.moveCount != count+1 { errors.append("Presentation committed a different puzzle result") }
                if duration*pace.speed>8.5 { errors.append("Pacing budget exceeded") }
                results.append(["puzzle":puzzle.rawValue,"pace":pace.rawValue,"presentation":mode.rawValue,"seconds":duration,"move":index,"units":move.amount])
            }
            if !session.state.solved { errors.append("Mixed-presentation solution did not solve") }
            let checkpoint=try JSONDecoder().decode(LabComparisonSave.self,from:session.checkpointData())
            let reloaded=FluidBoardSession(defaults:nil,device:device,library:lib,restoredSave:checkpoint)
            if reloaded.state != session.state || reloaded.game.history != session.game.history || reloaded.pace != pace || reloaded.puzzle != puzzle { errors.append("Session reload lost progress or preferences") }
            reloaded.changePuzzle(puzzle == .firstSort ? .lastDrops:.firstSort)
            reloaded.changePuzzle(puzzle)
            if reloaded.state != session.state || reloaded.game.history != session.game.history { errors.append("Puzzle switch lost saved progress") }
            if reloaded.state.colors != stableIDs { errors.append("Reload changed color inventory") }
            // Undo crosses both rendering implementations, including the solved state.
            for index in states.indices.reversed() {
                session.changePresentation(index%2 == 0 ? .fluid:.classic)
                session.undo()
                if session.state != states[index] { errors.append("Cross-presentation undo failed") }
            }
            if session.state != original { errors.append("Undo did not restore original puzzle") }
            session.changePresentation(.classic)
            _=session.begin(original.solution()!.first!,automaticClock:false)
            session.advanceClassic(deltaTime:0.05);session.reset()
            if session.busy || session.state != original || session.moveCount != 0 { errors.append("Classic reset failed") }
            // Checkpoint encoding preserves both puzzle state and full undo history.
            var game=LabBoardGame(state:original);let move=game.begin(from:route[0].source,to:route[0].destination)!;_=game.commit(move)
            let restored=try JSONDecoder().decode(LabBoardGame.self,from:JSONEncoder().encode(game))
            if restored.state != game.state || restored.history != game.history { errors.append("Saved checkpoint changed history") }
        }}
        let fallback=FluidBoardSession(defaults:nil,device:nil)
        if fallback.presentation != .classic || fallback.renderer != nil { errors.append("Classic fallback requires Metal") }
        let fallbackMove=fallback.state.solution()!.first!
        _=fallback.begin(fallbackMove,automaticClock:false)
        for _ in 0..<500 { fallback.advanceClassic(deltaTime:1/60) }
        if fallback.moveCount != 1 { errors.append("Classic fallback cannot complete a move") }
        let classic=ImageRenderer(content:LabClassicBoardView(state:.firstSort,pour:nil).frame(width:1000,height:650).background(Color(red:0.026,green:0.043,blue:0.060)))
        if let cg=classic.cgImage { let rep=NSBitmapImageRep(cgImage:cg);try rep.representation(using:.png,properties:[:])!.write(to:output.appendingPathComponent("classic.png")) }
        let pour=LabClassicPour(move:LabBoardState.firstSort.solution()!.first!,time:3)
        let mid=ImageRenderer(content:LabClassicBoardView(state:.firstSort,pour:pour).frame(width:1000,height:650).background(Color(red:0.026,green:0.043,blue:0.060)))
        if let cg=mid.cgImage { let rep=NSBitmapImageRep(cgImage:cg);try rep.representation(using:.png,properties:[:])!.write(to:output.appendingPathComponent("classic-pour.png")) }
        let portrait=ImageRenderer(content:LabClassicBoardView(state:.firstSort,pour:nil).frame(width:600,height:760).background(Color(red:0.026,green:0.043,blue:0.060)))
        if let cg=portrait.cgImage { let rep=NSBitmapImageRep(cgImage:cg);try rep.representation(using:.png,properties:[:])!.write(to:output.appendingPathComponent("classic-portrait.png")) }
        let report:[String:Any]=["moves":results,"errors":errors,"device":device.name]
        try JSONSerialization.data(withJSONObject:report,options:[.prettyPrinted,.sortedKeys]).write(to:output.appendingPathComponent("report.json"))
        print("Comparison checks: \(results.count) moves; errors: \(errors)")
        if !errors.isEmpty { exit(1) }
    }
}
