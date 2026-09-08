import Foundation
import MetalKit
import AppKit

@main
struct FluidLabValidation {
    @MainActor static func main() throws {
        let arguments=CommandLine.arguments
        func value(_ name:String,_ fallback:String) -> String {
            guard let i=arguments.firstIndex(of:name), i+1<arguments.count else { return fallback }
            return arguments[i+1]
        }
        let output=URL(fileURLWithPath:value("--output","/tmp/vials-fluid-validation"))
        try FileManager.default.createDirectory(at:output,withIntermediateDirectories:true)
        let device=MTLCreateSystemDefaultDevice()!
        let library=try device.makeLibrary(URL:URL(fileURLWithPath:value("--library","default.metallib")))
        let engine=try LabRenderer(device:device,library:library)
        engine.aimOffset=Float(value("--aim","0"))!
        let material=value("--material","water")
        engine.reset(twoColors:material == "dyes")
        engine.viscosity=material == "thick" ? 0.32 : 0.08
        if material == "points" { engine.pointMode=true }
        let frames=Int(value("--frames","1260"))!
        let fps=Float(value("--fps","60"))!
        let pourFrame=Int(value("--pour-frame",String(Int(fps*2))))!
        let width=Int(value("--width","900"))!, height=Int(value("--height","650"))!
        let captures=Set(value("--capture","119,479,539,599,1199").split(separator:",").compactMap { Int($0) })
        let descriptor=MTLTextureDescriptor.texture2DDescriptor(pixelFormat:.bgra8Unorm_srgb,width:width,height:height,mipmapped:false)
        descriptor.storageMode = .shared; descriptor.usage = [.renderTarget,.shaderRead]
        let texture=device.makeTexture(descriptor:descriptor)!
        var errors:[String]=[]
        let cylinder=LabVesselProfile(name:"Cylinder",height:2,knots:[(0,0.5),(1,0.5)])
        if abs(cylinder.volume(at:2)-Float.pi*0.5)>0.0001 { errors.append("Cylinder volume integration failed") }
        let cone=LabVesselProfile(name:"Cone",height:3,knots:[(0,0),(1,1)])
        if abs(cone.volume(at:3)-Float.pi)>0.0001 { errors.append("Cone volume integration failed") }
        let profiles=engine.profiles
        if abs(profiles[0].usableVolume-profiles[1].usableVolume)>0.0001 { errors.append("Vessels do not share unit volume") }
        for profile in profiles {
            for step in 0...100 {
                let v=profile.usableVolume*Float(step)/100
                if abs(profile.volume(at:profile.height(for:v))-v)>0.0001 { errors.append("Volume inversion failed") }
            }
        }
        // Sample the vessel surface throughout the entire trajectory. The source
        // must clear the receiver, including its wider lip, before pouring.
        for tick in 0...330 {
            let pair=labVessels(time:Float(tick)*0.05,profiles:profiles,horizontalOffset:engine.aimOffset)
            for ring in 0...20 {
                let y=Float(ring)/20*profiles[0].height
                let r=profiles[0].radius(at:y)+0.035
                for segment in 0..<24 {
                    let a=Float(segment)/24*2*Float.pi
                    let world=pair[0].world*SIMD4<Float>(r*cos(a),y,r*sin(a),1)
                    let local=(pair[1].inverseWorld*world).xyz
                    if local.y>=0 && local.y<=profiles[1].height && simd_length(SIMD2(local.x,local.z)) < profiles[1].radius(at:local.y)+0.035 {
                        errors.append("Vessel collision along path at time \(Float(tick)*0.05)")
                    }
                }
            }
        }
        var samples:[[String:Any]]=[]
        var gpuTimes:[Double]=[]
        var previous=engine.particleSamples()
        var crossingIDs=Set<Int>()
        var crossings:[[Float]]=[]
        let start=Date()
        for frame in 0..<frames {
            if frame == pourFrame { engine.beginPour() }
            let command=engine.encodeFrame(target:texture,deltaTime:1.0/fps)
            command.waitUntilCompleted()
            if command.status == .error { throw command.error ?? LabError.message("GPU command failed") }
            let stats=engine.snapshot()
            let current=engine.particleSamples()
            let plane:Float=profiles[1].height+0.18
            for i in current.indices where !crossingIDs.contains(i) && previous[i].position.y>plane && current[i].position.y<=plane && current[i].position.w != 0 {
                let a=previous[i].position, b=current[i].position
                let t=(plane-a.y)/(b.y-a.y)
                crossings.append([Float(frame-pourFrame)/fps,a.x+(b.x-a.x)*t,a.z+(b.z-a.z)*t])
                crossingIDs.insert(i)
            }
            previous=current
            let total=stats.source+stats.destination+stats.airborne+stats.spilled+stats.nonFinite
            if total != engine.particleCount { errors.append("Particle inventory changed at frame \(frame)") }
            if frame < pourFrame && stats.source != engine.particleCount { errors.append("Initial fill escaped before pouring at frame \(frame)") }
            if stats.nonFinite>0 { errors.append("Non-finite particles at frame \(frame)"); break }
            if frame>60 { gpuTimes.append(stats.gpuMilliseconds) }
            if frame%60 == 59 || captures.contains(frame) {
                let sample:[String:Any] = ["frame":frame,"simulationSeconds":engine.simulationTime,
                    "source":stats.source,"destination":stats.destination,"inFlight":stats.airborne,
                    "onTray":stats.spilled,"gpuMs":stats.gpuMilliseconds,"maximumSpeed":stats.maximumSpeed]
                samples.append(sample)
                print("frame \(frame): A \(stats.source), B \(stats.destination), flying \(stats.airborne), tray \(stats.spilled), GPU \(String(format:"%.2f",stats.gpuMilliseconds)) ms")
                fflush(stdout)
            }
            if captures.contains(frame) { try save(texture,to:output.appendingPathComponent("\(material)-\(frame).png")) }
        }
        gpuTimes.sort()
        let stats=engine.snapshot()
        if frames > Int(fps*20), Double(stats.destination)/Double(engine.particleCount) < 0.90 {
            errors.append("Less than 90% of the pour reached the receiving vessel")
        }
        // Reset after a completed pour, freeze simulation, then resume: no stale
        // in-flight state and no movement while paused.
        engine.reset(twoColors:material == "dyes")
        let resetSamples=engine.particleSamples()
        engine.paused=true
        let frozen=engine.encodeFrame(target:texture,deltaTime:1.0/fps)
        frozen.waitUntilCompleted()
        let frozenSamples=engine.particleSamples()
        if zip(resetSamples,frozenSamples).contains(where: { $0.position != $1.position }) { errors.append("Paused simulation moved particles") }
        if engine.pourTime != nil || engine.snapshot().source != engine.particleCount { errors.append("Reset did not restore the source") }
        if material == "water" {
            engine.reset()
            engine.beginPour()
            for _ in 0..<540 {
                let c=engine.encodeFrame(target:texture,deltaTime:1.0/60)
                c.waitUntilCompleted()
            }
            if engine.snapshot().destination == 0 { errors.append("Mid-pour reset fixture never reached the receiver") }
            engine.reset()
            if engine.snapshot().source != engine.particleCount || engine.pourTime != nil { errors.append("Mid-pour reset left stale liquid") }
        }
        let report:[String:Any] = ["device":device.name,"material":material,"particles":engine.particleCount,
            "frames":frames,"fps":fps,"resolution":[width,height],"elapsedSeconds":Date().timeIntervalSince(start),
            "gpuMedianMs":gpuTimes.isEmpty ? 0:gpuTimes[gpuTimes.count/2],
            "gpuP95Ms":gpuTimes.isEmpty ? 0:gpuTimes[min(gpuTimes.count-1,Int(Double(gpuTimes.count)*0.95))],
            "capturedFraction":Double(stats.destination)/Double(engine.particleCount),
            "spilledFraction":Double(stats.spilled)/Double(engine.particleCount),"errors":errors,"samples":samples,"mouthCrossings":crossings,"aimOffset":engine.aimOffset]
        try JSONSerialization.data(withJSONObject:report,options:[.prettyPrinted,.sortedKeys]).write(to:output.appendingPathComponent("\(material)-report.json"))
        print("REPORT: \(output.path)/\(material)-report.json")
        if !errors.isEmpty { print(errors.joined(separator:"\n")); exit(1) }
    }
    @MainActor private static func save(_ texture:MTLTexture,to url:URL) throws {
        let width=texture.width,height=texture.height
        var pixels=[UInt8](repeating:0,count:width*height*4)
        texture.getBytes(&pixels,bytesPerRow:width*4,from:MTLRegionMake2D(0,0,width,height),mipmapLevel:0)
        let image=NSBitmapImageRep(bitmapDataPlanes:nil,pixelsWide:width,pixelsHigh:height,bitsPerSample:8,
            samplesPerPixel:4,hasAlpha:true,isPlanar:false,colorSpaceName:.deviceRGB,bytesPerRow:width*4,bitsPerPixel:32)!
        let target=image.bitmapData!
        for i in stride(from:0,to:pixels.count,by:4) {
            target[i]=pixels[i+2]; target[i+1]=pixels[i+1]; target[i+2]=pixels[i]; target[i+3]=255
        }
        try image.representation(using:.png,properties:[:])!.write(to:url)
    }
}
