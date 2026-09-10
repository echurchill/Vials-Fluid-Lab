import SwiftUI
import MetalKit
import AppKit
@main struct PlanarSessionValidation {
    @MainActor static func main() async throws {
        let args=CommandLine.arguments
        func option(_ key:String,_ fallback:String)->String { guard let i=args.firstIndex(of:key),i+1<args.count else { return fallback };return args[i+1] }
        let output=URL(fileURLWithPath:option("--output","/private/tmp"))
        try FileManager.default.createDirectory(at:output,withIntermediateDirectories:true)
        let device=MTLCreateSystemDefaultDevice()!
        let lib=try device.makeLibrary(URL:URL(fileURLWithPath:option("--library","/private/tmp/vials-2d-build/Build/Products/Release/VialsFluidLab.app/Contents/Resources/default.metallib")))
        let session=FluidBoardSession(defaults:nil,device:device,library:lib)
        session.changePuzzle(.greenArrival);session.changePace(.quick);session.changePresentation(.fluid2D)
        let start=session.state,move=start.solution()!.first!
        func require(_ result:Bool,_ message:String) { if !result { fatalError(message) } }
        require(session.begin(move,automaticClock:false),"2D begin")
        session.advance2D(deltaTime:1/60)
        let time=session.fluid2D.time,samples=session.fluid2D.particles,clocks=session.fluid2D.materialTimes
        session.togglePause();session.advance2D(deltaTime:0.05)
        require(session.fluid2D.time==time && session.fluid2D.particles==samples && session.fluid2D.materialTimes==clocks,"Pause changed particles or materials")
        session.togglePause();session.setSuspended(true);session.advance2D(deltaTime:0.05)
        require(session.fluid2D.time==time && session.fluid2D.materialTimes==clocks,"Background advanced 2D")
        session.setSuspended(false)
        session.changePresentation(.classic);session.changePuzzle(.firstSort);session.undo()
        require(session.presentation == .fluid2D && session.puzzle == .greenArrival && session.busy,"Busy guards")
        for _ in 0..<900 where session.busy { session.advance2D(deltaTime:1/60) }
        require(session.state==start.applying(move) && session.moveCount==1,"2D commit")
        let data=try session.checkpointData(),save=try JSONDecoder().decode(LabComparisonSave.self,from:data)
        let reloaded=FluidBoardSession(defaults:nil,device:device,library:lib,restoredSave:save)
        require(reloaded.presentation == .fluid2D && reloaded.state==session.state,"2D reload")
        let settled=session.fluid2D.particles
        session.changePresentation(.classic);session.changePresentation(.fluid2D)
        require(session.fluid2D.particles==settled,"Switch rebuilt settled 2D particles")
        for mode in LabBoardPresentation.allCases { session.changePresentation(mode);require(session.state==reloaded.state,"Switch changed state") }
        session.undo();require(session.state==start,"Undo after 3D switch")
        session.changePresentation(.fluid2D)
        require(session.begin(move,automaticClock:false),"Restart 2D")
        session.advance2D(deltaTime:0.05);session.reset()
        require(!session.busy && !session.fluid2D.busy && session.state==start,"Reset pending")
        session.changePresentation(.classic);require(session.begin(move,automaticClock:false),"Classic begin")
        for _ in 0..<500 { session.advanceClassic(deltaTime:1/60) }
        session.changePresentation(.fluid2D);session.undo();require(session.state==start,"Undo Classic in 2D")
        // Planar rendering is independent of a Metal simulation device.
        let fallback=FluidBoardSession(defaults:nil,device:nil)
        fallback.changePresentation(.fluid2D);require(fallback.begin(fallback.state.solution()!.first!,automaticClock:false),"2D fallback begin")
        for _ in 0..<1000 where fallback.busy { fallback.advance2D(deltaTime:1/60) }
        require(fallback.moveCount==1,"2D fallback finish")
        session.changePresentation(.fluid)
        let descriptor=MTLTextureDescriptor.texture2DDescriptor(pixelFormat:.bgra8Unorm_srgb,width:600,height:390,mipmapped:false)
        descriptor.usage=[.renderTarget,.shaderRead];descriptor.storageMode = .shared
        let target=device.makeTexture(descriptor:descriptor)!
        require(session.begin(move,automaticClock:false),"3D begin after 2D")
        for _ in 0..<900 where session.busy { await session.renderer!.encodeFrame(target:target,deltaTime:1/60).completed() }
        require(session.state==start.applying(move),"3D move after 2D failed")
        session.changePresentation(.fluid2D);session.undo();require(session.state==start,"Undo 3D in 2D")
        var engine=session.fluid2D
        func capture(_ name:String,size:CGSize=CGSize(width:1000,height:650)) throws {
            let view=LabFluid2DView(engine:engine).frame(width:size.width,height:size.height).background(Color(red:0.026,green:0.043,blue:0.060))
            guard let cg=ImageRenderer(content:view).cgImage else { fatalError("Capture failed") }
            try NSBitmapImageRep(cgImage:cg).representation(using:.png,properties:[:])!.write(to:output.appendingPathComponent("2d-\(name).png"))
        }
        try capture("idle");try capture("portrait",size:CGSize(width:600,height:760))
        _=engine.begin(move)
        for frame in 0..<480 {
            engine.advance(deltaTime:1/60)
            if [90,140,180,210,260,340,430].contains(frame) { try capture("pour-\(frame)") }
        }
        try capture("end")
        let remaining=engine.game.state.solution()!
        var impactColors:Set<Int>=[]
        for (index,nextMove) in remaining.enumerated() {
            let last=index==remaining.count-1
            if last { try capture("nearly-full-before") }
            _=engine.begin(nextMove)
            var captured=false,frame=0
            while engine.busy && frame<1000 {
                engine.advance(deltaTime:1/60);frame+=1
                if !impactColors.contains(nextMove.color),engine.surfaces[nextMove.destination].energy>0.65 {
                    try capture("impact-color-\(nextMove.color)");impactColors.insert(nextMove.color)
                }
                if last && frame==20 { try capture("nearly-full-selected") }
                if last && !captured && engine.phase=="Final settling" {
                    try capture("full-before-cleanup");captured=true
                }
            }
            require(!engine.busy,"Capture route timed out")
            if last { try capture("full-after-cleanup") }
        }
        // Delayed updates retain their fixed-step time rather than slowing a pour.
        var delayed=LabFluid2D(game:LabBoardGame(state:start));delayed.quickMotion=true
        _=delayed.begin(move)
        let snapshot=delayed
        delayed.advance(deltaTime:0.2)
        require(delayed.time>0.09 && delayed.time<0.11 && delayed.pendingSimulationSeconds>0.09,"Worker batch is not bounded with retained debt")
        delayed.advance(deltaTime:0)
        require(abs(delayed.time+delayed.pendingSimulationSeconds-0.2)<0.0001 && delayed.pendingSimulationSeconds<=LabFluid2D.step+0.00001,"Delayed frame lost simulation time")
        require(snapshot.time==0 && snapshot.particles != delayed.particles,"Snapshot mutated with solver")
        let worker=Lab2DWorker(snapshot)
        let advanced=await worker.advance(deltaTime:0.05,speed:1)
        require(advanced.time>0 && snapshot.time==0,"Worker snapshot isolation")

        // Exercise the actual asynchronous clock and invalidate in-flight results.
        session.reset();session.changePace(.quick)
        require(session.begin(move),"Automatic worker start")
        try await Task.sleep(for:.milliseconds(120))
        session.togglePause()
        let pausedFrame=session.fluid2D
        try await Task.sleep(for:.milliseconds(120))
        require(session.fluid2D.time==pausedFrame.time && session.fluid2D.particles==pausedFrame.particles && session.fluid2D.surfaces==pausedFrame.surfaces && session.fluid2D.splashes==pausedFrame.splashes,"Worker advanced a paused board")
        session.togglePause();session.setSuspended(true)
        let suspendedFrame=session.fluid2D
        try await Task.sleep(for:.milliseconds(120))
        require(session.fluid2D.time==suspendedFrame.time,"Worker advanced a suspended board")
        session.setSuspended(false)
        try await Task.sleep(for:.milliseconds(40))
        session.reset()
        try await Task.sleep(for:.milliseconds(120))
        require(!session.busy && session.state==start && session.fluid2D.time==0,"Stale worker overwrote reset")
        require(session.begin(move),"New worker after reset")
        for _ in 0..<600 where session.busy { try await Task.sleep(for:.milliseconds(16)) }
        require(session.state==start.applying(move) && session.moveCount==1,"Automatic worker commit")
        print("PASS: retained delayed-frame time, bounded worker batches, immutable snapshots, automatic pause/suspend/reset and commit")
        print("PASS: 2D commit, pause, background suspension, busy guards, reset, saved-state reload, three-way presentation switching, cross-presentation undo, no-Metal fallback and landscape/portrait captures")
    }
}
