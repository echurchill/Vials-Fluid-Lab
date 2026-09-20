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
        let pacingBudget=Float(option("--pacing-budget","8.5"))!
        let desc=MTLTextureDescriptor.texture2DDescriptor(pixelFormat:.bgra8Unorm_srgb,width:width,height:height,mipmapped:false)
        desc.storageMode = .shared;desc.usage=[.renderTarget,.shaderRead]
        let texture=device.makeTexture(descriptor:desc)!
        var errors:[String]=[],results:[[String:Any]]=[]
        let fixture=option("--fixture","level")
        if let puzzle=LabBoardPuzzle(rawValue:fixture) { renderer.reset(state:puzzle.initial) }
        if fixture == "mixingOneUnit" { renderer.reset(state:LabBoardPuzzle.warmBlend.initial) }
        if fixture == "mixingMeasuredDose" { renderer.reset(state:LabBoardPuzzle.measuredBatch.initial) }
        if fixture == "pear" { renderer.reset(state:LabBoardState(layers:[[],[],[],[0,1,1,1]])) }
        if fixture == "three" { renderer.reset(state:LabBoardState(layers:[[0,1,1,1],[],[],[]])) }
        if fixture == "partial" { renderer.reset(state:LabBoardState(layers:[[0,0],[0,0,0],[],[]])) }
        if fixture == "last" { renderer.reset(state:LabBoardState(layers:[[0],[],[],[]])) }
        if fixture == "floating" {
            // Exact Five Streams state immediately before the reported E→G
            // pour that left both participating vials visibly fragmented.
            renderer.reset(state:LabBoardState(
                layers:[[1,1,1],[2],[4,3,4],[1,0,2,2,2],[2,1,3,3],[4,0,4],[3,3,3],[0,0]],
                capacities:[4,3,4,5,5,3,5,4]))
        }
        if fixture == "level16-complete" {
            var state=LabBoardPuzzle.valveCircuit.initial
            state=state.applying(state.move(from:1,to:6)!)!
            state=state.applying(state.move(from:2,to:6)!)!
            renderer.reset(state:state)
        }
        renderer.funnelEnabled = !args.contains("--no-funnel")
        renderer.playbackSpeed=Float(option("--speed","1"))!
        let initial=renderer.game.state
        // Exact rules: incompatible colors, empty source, same vial, capacity.
        if initial.move(from:0,to:0) != nil || initial.move(from:-1,to:0) != nil { errors.append("Illegal move accepted") }
        if fixture == "level" && initial.move(from:0,to:1) != nil { errors.append("Different top colors accepted") }
        guard let solution=initial.solution() ?? (fixture == "level" ? nil:[]) else { throw LabError.message("Initial level has no solution") }
        let route: [(Int,Int)] = fixture == "mixingOneUnit" ? [(0,2)] : fixture == "mixingMeasuredDose" ? [(1,4)] : (fixture == "shortest" || LabBoardPuzzle(rawValue:fixture) != nil) ? solution.map { ($0.source,$0.destination) } : fixture == "pear" ? [(3,1)] : fixture == "floating" ? [(4,6)] : fixture == "level" ? [(0,3),(1,0),(2,3),(2,0),(1,3)] : [(0,fixture == "partial" ? 1:3)]
        print("Fixture \(fixture), particles \(renderer.particleCount), solution \(solution.count) moves")
        renderer.encodeFrame(target:texture,deltaTime:0).waitUntilCompleted()
        try save(texture,to:output.appendingPathComponent("ready.png"))
        if args.contains("--ready-only") { return }
        var observedCommits=0
        renderer.onUpdate={ _,_,_ in if renderer.game.pending == nil { observedCommits=renderer.game.moveCount } }
        var snapshots:[[LabParticle]]=[],states:[LabBoardState]=[]
        var maxPenetration:Float=0,maxPenetrationMove=0,maxPenetrationFrame=0
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
            var duration:Float=0
            for frame in 0..<Int(fps*36) {
                duration=Float(frame+1)/fps
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
                        let profile=renderer.profiles[pair.0],y=Float(ring)/16*profile.height
                        let r=profile.radius(at:y)+0.035,rz=profile.radius(at:y)*profile.depthScale+0.035
                        let a=Float(segment)/24*2*Float.pi
                        let point=vessels[pair.0].world*SIMD4<Float>(r*cos(a),y,rz*sin(a),1)
                        for other in renderer.profiles.indices where other != pair.0 {
                            let q=(vessels[other].inverseWorld*point).xyz
                            if q.y>=0 && q.y<=renderer.profiles[other].height {
                                let otherRadius=renderer.profiles[other].radius(at:q.y)+0.035
                                let otherDepth=renderer.profiles[other].radius(at:q.y)*renderer.profiles[other].depthScale+0.035
                                let metric=simd_length(SIMD2(q.x/otherRadius,q.z/otherDepth))
                                let penetration=max(0,1-metric)*min(otherRadius,otherDepth)
                                if penetration>maxPenetration {maxPenetration=penetration;maxPenetrationMove=index;maxPenetrationFrame=frame}
                            }
                        }
                    }}
                }
                if frame%120 == 0 {
                    print("move \(index) frame \(frame) \(renderer.phase) tilt \(renderer.tilt) arrived \(metrics.arrived)/\(expected.amount*LabBoardRenderer.particlesPerUnit) outside \(metrics.outside)")
                    fflush(stdout)
                }
                if frame == Int(fps*3/renderer.playbackSpeed) || frame == Int(fps*5/renderer.playbackSpeed) { try save(texture,to:output.appendingPathComponent("move-\(index)-\(frame).png")) }
                if renderer.game.pending == nil { break }
            }
            gpu.sort();wall.sort()
            if duration*renderer.playbackSpeed>pacingBudget { errors.append("Turn exceeded the \(pacingBudget)-second pacing budget") }
            let committed=renderer.game.moveCount == index+1
            if committed && observedCommits != renderer.game.moveCount { errors.append("Commit did not notify the UI before resting") }
            if !committed { errors.append("Move \(index) did not commit: \(renderer.lastOutcome)") }
            let samples=renderer.particleSamples()
            let activeOwners=Set([pair.0,pair.1])
            for (before,after) in zip(snapshots[index],samples) where !activeOwners.contains(Int(before.position.w)) {
                if before.position != after.position { errors.append("Inactive vial moved during another pair's pour");break }
            }
            if samples.count != initial.colors.count*LabBoardRenderer.particlesPerUnit { errors.append("Particle count changed") }
            let expectedState=states[index].applying(expected)!
            if committed && renderer.game.state != expectedState { errors.append("Wrong puzzle state after move \(index)") }
            if renderer.correctionCount > Int(Float(expected.amount*LabBoardRenderer.particlesPerUnit)*0.05) { errors.append("Correction exceeded 5 percent") }
            if committed && fixture == "floating" {
                let reference=try LabBoardRenderer(device:device,library:lib)
                reference.reset(state:expectedState)
                let canonical=reference.particleSamples(),ids=Set(expectedState.stacks[pair.0]+expectedState.stacks[pair.1])
                func positions(_ values:[LabParticle],_ parcel:Int)->[SIMD3<Float>] {
                    values.filter {Int($0.visual.y)==parcel}.map(\.position.xyz).sorted {
                        $0.x != $1.x ? $0.x<$1.x:($0.y != $1.y ? $0.y<$1.y:$0.z<$1.z)
                    }
                }
                if ids.contains(where:{positions(samples,$0) != positions(canonical,$0)}) {
                    errors.append("Accepted pour left detached particles instead of a settled fluid body")
                }
            }
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
            results.append(["guidedParticles":renderer.lastMetrics.guided,"durationSeconds":duration,"move":index,"source":pair.0,"destination":pair.1,"units":expected.amount,"arrivalBeforeCorrection":renderer.arrivalBeforeCorrection,"correctedParticles":renderer.correctionCount,"committed":committed,"gpuMedianMs":gpu.isEmpty ? 0:gpu[gpu.count/2],"frameMedianMs":wall.isEmpty ? 0:wall[wall.count/2]])
            try save(texture,to:output.appendingPathComponent("after-\(index).png"))
            if !errors.isEmpty { break }
        }
        if maxPenetration>0.02 { errors.append("Vessels intersected by \(maxPenetration) scene units at move \(maxPenetrationMove), frame \(maxPenetrationFrame)") }
        if (["level","shortest"].contains(fixture) || LabBoardPuzzle(rawValue:fixture) != nil), !renderer.game.state.solved { errors.append("The complete solution did not solve the board") }
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
        let report:[String:Any]=["playbackSpeed":renderer.playbackSpeed,"funnelEnabled":renderer.funnelEnabled,"fixture":fixture,"device":device.name,"fps":fps,"resolution":[width,height],"particles":initial.colors.count*LabBoardRenderer.particlesPerUnit,"vialCount":initial.stacks.count,"maximumVesselPenetration":maxPenetration,"maximumVesselPenetrationMove":maxPenetrationMove,"maximumVesselPenetrationFrame":maxPenetrationFrame,"moves":results,"errors":errors]
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
