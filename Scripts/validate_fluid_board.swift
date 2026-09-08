import Foundation
import MetalKit
import AppKit

@main struct BoardValidation {
    @MainActor static func main() throws {
        let args=CommandLine.arguments
        func option(_ name:String,_ fallback:String) -> String { guard let i=args.firstIndex(of:name),i+1<args.count else { return fallback };return args[i+1] }
        let output=URL(fileURLWithPath:option("--output","/tmp/vials-board-validation"))
        try FileManager.default.createDirectory(at:output,withIntermediateDirectories:true)
        let device=MTLCreateSystemDefaultDevice()!
        let lib=try device.makeLibrary(URL:URL(fileURLWithPath:option("--library","default.metallib")))
        let renderer=try LabBoardRenderer(device:device,library:lib)
        let fps=Float(option("--fps","60"))!,width=Int(option("--width","1000"))!,height=Int(option("--height","650"))!
        let desc=MTLTextureDescriptor.texture2DDescriptor(pixelFormat:.bgra8Unorm_srgb,width:width,height:height,mipmapped:false)
        desc.storageMode = .shared;desc.usage=[.renderTarget,.shaderRead]
        let texture=device.makeTexture(descriptor:desc)!
        var errors:[String]=[],results:[[String:Any]]=[]
        let fixture=option("--fixture","level")
        if fixture == "pear" { renderer.reset(state:LabBoardState(layers:[[],[],[],[0,1,1,1]])) }
        if fixture == "three" { renderer.reset(state:LabBoardState(layers:[[0,1,1,1],[],[],[]])) }
        if fixture == "partial" { renderer.reset(state:LabBoardState(layers:[[0,0],[0,0,0],[],[]])) }
        if fixture == "last" { renderer.reset(state:LabBoardState(layers:[[0],[],[],[]])) }
        let initial=renderer.game.state
        // Exact rules: incompatible colors, empty source, same vial, capacity.
        if initial.move(from:0,to:0) != nil || initial.move(from:-1,to:0) != nil { errors.append("Illegal move accepted") }
        if fixture == "level" && initial.move(from:0,to:1) != nil { errors.append("Different top colors accepted") }
        guard let solution=initial.solution() ?? (fixture == "level" ? nil:[]) else { throw LabError.message("Initial level has no solution") }
        let route: [(Int,Int)] = fixture == "shortest" ? solution.map { ($0.source,$0.destination) } : fixture == "pear" ? [(3,1)] : fixture == "level" ? [(0,3),(1,0),(2,3),(2,0),(1,3)] : [(0,fixture == "partial" ? 1:3)]
        print("Fixture \(fixture), particles \(renderer.particleCount), shortest solution \(solution.count) moves")
        renderer.encodeFrame(target:texture,deltaTime:0).waitUntilCompleted()
        try save(texture,to:output.appendingPathComponent("ready.png"))
        var observedCommits=0
        renderer.onUpdate={ _,_,_ in if renderer.game.pending == nil { observedCommits=renderer.game.moveCount } }
        var snapshots:[[LabParticle]]=[],states:[LabBoardState]=[]
        var maxPenetration:Float=0
        for (index,pair) in route.enumerated() {
            snapshots.append(renderer.particleSamples());states.append(renderer.game.state)
            guard let expected=renderer.game.state.move(from:pair.0,to:pair.1),renderer.begin(from:pair.0,to:pair.1) else { errors.append("Could not start legal move \(index)");break }
            if renderer.begin(from:pair.0,to:pair.1) { errors.append("Overlapping move accepted") }
            // Pause must preserve both the simulation clock and particle state.
            renderer.paused=true
            let frozen=renderer.particleSamples(),clock=renderer.simulationTime
            renderer.encodeFrame(target:texture,deltaTime:1).waitUntilCompleted()
            if renderer.simulationTime != clock || zip(frozen,renderer.particleSamples()).contains(where: { $0.position != $1.position }) { errors.append("Pause advanced physics") }
            if renderer.undo() { errors.append("Undo accepted during a pour") }
            renderer.paused=false
            var gpu:[Double]=[],wall:[Double]=[]
            for frame in 0..<Int(fps*36) {
                let start=Date()
                let command=renderer.encodeFrame(target:texture,deltaTime:1/fps)
                command.waitUntilCompleted()
                if command.status == .error { throw command.error ?? LabError.message("GPU command failed") }
                wall.append(Date().timeIntervalSince(start)*1000)
                let metrics=renderer.lastMetrics
                if metrics.nonFinite>0 || metrics.wrongParcel>0 { errors.append("Wrong parcel escaped or nonfinite state at move \(index), frame \(frame)");break }
                if renderer.game.pending != nil { gpu.append(metrics.gpuMilliseconds) }
                if frame%10 == 0 {
                    let vessels=renderer.currentVessels
                    for ring in 0...16 { for segment in 0..<24 {
                        let profile=renderer.profiles[pair.0],y=Float(ring)/16*profile.height,r=profile.radius(at:y)+0.035
                        let a=Float(segment)/24*2*Float.pi
                        let point=vessels[pair.0].world*SIMD4<Float>(r*cos(a),y,r*sin(a),1)
                        for other in 0..<4 where other != pair.0 {
                            let q=(vessels[other].inverseWorld*point).xyz
                            if q.y>=0 && q.y<=renderer.profiles[other].height { maxPenetration=max(maxPenetration,renderer.profiles[other].radius(at:q.y)+0.035-simd_length(SIMD2(q.x,q.z))) }
                        }
                    }}
                }
                if frame%120 == 0 {
                    print("move \(index) frame \(frame) \(renderer.phase) tilt \(renderer.tilt) arrived \(metrics.arrived)/\(expected.amount*LabBoardRenderer.particlesPerUnit) outside \(metrics.outside)")
                    fflush(stdout)
                }
                if frame == Int(fps*8) || frame == Int(fps*12) { try save(texture,to:output.appendingPathComponent("move-\(index)-\(frame).png")) }
                if renderer.game.pending == nil { break }
            }
            gpu.sort();wall.sort()
            let committed=renderer.game.moveCount == index+1
            if committed && observedCommits != renderer.game.moveCount { errors.append("Commit did not notify the UI before resting") }
            if !committed { errors.append("Move \(index) did not commit: \(renderer.lastOutcome)") }
            let samples=renderer.particleSamples()
            if samples.count != initial.colors.count*LabBoardRenderer.particlesPerUnit { errors.append("Particle count changed") }
            let expectedState=states[index].applying(expected)!
            if committed && renderer.game.state != expectedState { errors.append("Wrong puzzle state after move \(index)") }
            if renderer.correctionCount > Int(Float(expected.amount*LabBoardRenderer.particlesPerUnit)*0.05) { errors.append("Correction exceeded 5 percent") }
            // Unlike-colored layers must retain their vertical order when settled.
            if committed {
                for (owner,stack) in expectedState.stacks.enumerated() {
                    for boundary in 1..<max(1,stack.count) where expectedState.colors[stack[boundary-1]] != expectedState.colors[stack[boundary]] {
                        let lower=Set(stack[..<boundary]),upper=Set(stack[boundary...])
                        let low=samples.filter { Int($0.position.w)==owner && lower.contains(Int($0.visual.y)) }.map { $0.position.y }.max()!
                        let high=samples.filter { Int($0.position.w)==owner && upper.contains(Int($0.visual.y)) }.map { $0.position.y }.min()!
                        if low > high+0.02 { errors.append("Different colors crossed their settled layer boundary") }
                    }
                }
            }
            for unit in initial.colors.indices {
                let group=samples.filter { Int($0.visual.y)==unit }
                if group.count != LabBoardRenderer.particlesPerUnit || group.contains(where: { Int($0.velocity.w) != initial.colors[unit] }) { errors.append("Color/unit inventory changed") }
                if committed {
                    let owner=expectedState.stacks.firstIndex { $0.contains(unit) }!
                    if group.contains(where: { Int($0.position.w) != owner }) { errors.append("Unit in wrong vessel after cleanup") }
                }
            }
            results.append(["move":index,"source":pair.0,"destination":pair.1,"units":expected.amount,"arrivalBeforeCorrection":renderer.arrivalBeforeCorrection,"correctedParticles":renderer.correctionCount,"committed":committed,"gpuMedianMs":gpu.isEmpty ? 0:gpu[gpu.count/2],"frameMedianMs":wall.isEmpty ? 0:wall[wall.count/2]])
            try save(texture,to:output.appendingPathComponent("after-\(index).png"))
            if !errors.isEmpty { break }
        }
        if maxPenetration>0.02 { errors.append("Vessels intersected by \(maxPenetration) scene units") }
        if ["level","shortest"].contains(fixture), !renderer.game.state.solved { errors.append("The complete solution did not solve the board") }
        // Undo restores exact particle snapshots and puzzle history, including colors.
        if renderer.game.pending == nil {
            for index in (0..<renderer.game.moveCount).reversed() {
                if !renderer.undo() || renderer.game.state != states[index] { errors.append("Undo did not restore puzzle state") }
                let now=renderer.particleSamples(),before=snapshots[index]
                if zip(now,before).contains(where: { $0.position != $1.position || $0.velocity != $1.velocity || $0.visual != $1.visual }) { errors.append("Undo did not restore the particle snapshot") }
            }
        }
        // Reset cancels an active pour and restores a reproducible board.
        renderer.reset()
        let resetParticles=renderer.particleSamples()
        _=renderer.begin(from:0,to:3)
        for _ in 0..<30 { renderer.encodeFrame(target:texture,deltaTime:1/fps).waitUntilCompleted() }
        renderer.reset()
        if renderer.game.pending != nil || renderer.game.moveCount != 0 || renderer.game.state != .firstSort || zip(resetParticles,renderer.particleSamples()).contains(where: { $0.position != $1.position }) { errors.append("Reset failed to cancel and restore") }
        let report:[String:Any]=["fixture":fixture,"device":device.name,"fps":fps,"resolution":[width,height],"particles":renderer.particleCount,"maximumVesselPenetration":maxPenetration,"moves":results,"errors":errors]
        try JSONSerialization.data(withJSONObject:report,options:[.prettyPrinted,.sortedKeys]).write(to:output.appendingPathComponent("report.json"))
        print("REPORT \(output.path)/report.json")
        if !errors.isEmpty { print(errors.joined(separator:"\n"));exit(1) }
    }
    @MainActor static func save(_ texture:MTLTexture,to url:URL) throws {
        let w=texture.width,h=texture.height
        var pixels=[UInt8](repeating:0,count:w*h*4)
        texture.getBytes(&pixels,bytesPerRow:w*4,from:MTLRegionMake2D(0,0,w,h),mipmapLevel:0)
        let rep=NSBitmapImageRep(bitmapDataPlanes:nil,pixelsWide:w,pixelsHigh:h,bitsPerSample:8,samplesPerPixel:4,hasAlpha:true,isPlanar:false,colorSpaceName:.deviceRGB,bytesPerRow:w*4,bitsPerPixel:32)!
        for i in stride(from:0,to:pixels.count,by:4) { rep.bitmapData![i]=pixels[i+2];rep.bitmapData![i+1]=pixels[i+1];rep.bitmapData![i+2]=pixels[i];rep.bitmapData![i+3]=255 }
        try rep.representation(using:.png,properties:[:])!.write(to:url)
    }
}
