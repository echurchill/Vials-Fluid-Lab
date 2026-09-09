import SwiftUI
import MetalKit
import AppKit
@main struct PlanarSessionValidation {
    @MainActor static func main() throws {
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
        let time=session.fluid2D.time,samples=session.fluid2D.particles
        session.togglePause();session.advance2D(deltaTime:0.05)
        require(session.fluid2D.time==time && session.fluid2D.particles==samples,"Pause changed particles")
        session.togglePause();session.setSuspended(true);session.advance2D(deltaTime:0.05)
        require(session.fluid2D.time==time,"Background advanced 2D")
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
        for _ in 0..<900 where session.busy { session.renderer!.encodeFrame(target:target,deltaTime:1/60).waitUntilCompleted() }
        require(session.state==start.applying(move),"3D move after 2D failed")
        session.changePresentation(.fluid2D);session.undo();require(session.state==start,"Undo 3D in 2D")
        let engine=session.fluid2D
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
        for (index,nextMove) in remaining.enumerated() {
            let last=index==remaining.count-1
            if last { try capture("nearly-full-before") }
            _=engine.begin(nextMove)
            var captured=false,frame=0
            while engine.busy && frame<1000 {
                engine.advance(deltaTime:1/60);frame+=1
                if last && frame==20 { try capture("nearly-full-selected") }
                if last && !captured && engine.phase=="Final settling" {
                    try capture("full-before-cleanup");captured=true
                }
            }
            require(!engine.busy,"Capture route timed out")
            if last { try capture("full-after-cleanup") }
        }
        print("PASS: 2D commit, pause, background suspension, busy guards, reset, saved-state reload, three-way presentation switching, cross-presentation undo, no-Metal fallback and landscape/portrait captures")
    }
}
