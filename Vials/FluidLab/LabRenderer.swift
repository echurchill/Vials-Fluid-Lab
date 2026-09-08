import Foundation
import MetalKit
import simd

@MainActor
final class LabRenderer: NSObject, MTKViewDelegate {
    let device: MTLDevice
    let profiles = LabVesselProfile.pair()
    let queue: MTLCommandQueue
    let library: MTLLibrary
    private(set) var particleCount = 0
    private(set) var simulationTime: Float = 0
    private(set) var pourTime: Float?
    var paused = false
    var pointMode = false
    var viscosity: Float = 0.08
    var orbit: Float = 0.35
    var aimOffset: Float = 0
    var onError: ((String) -> Void)?
    var onUpdate: ((LabFrameStats, String, Float) -> Void)?
    private var particles: MTLBuffer!
    private var profilesBuffer: MTLBuffer!
    private var heads: MTLBuffer!
    private var next: MTLBuffer!
    private var lambdas: MTLBuffer!
    private var deltas: MTLBuffer!
    private var velocities: MTLBuffer!
    private var meshes: [(MTLBuffer,Int)] = []
    private var kernels: [String: MTLComputePipelineState] = [:]
    private var depthPipeline: MTLRenderPipelineState!
    private var thicknessPipeline: MTLRenderPipelineState!
    private var composePipeline: MTLRenderPipelineState!
    private var glassPipeline: MTLRenderPipelineState!
    private var copyPipeline: MTLRenderPipelineState!
    private var depthState: MTLDepthStencilState!
    private var depth: MTLTexture!
    private var smoothA: MTLTexture!
    private var smoothB: MTLTexture!
    private var depthTest: MTLTexture!
    private var thickness: MTLTexture!
    private var scene: MTLTexture!
    private var glassDepth: MTLTexture!
    private var viewportSize = SIMD2<Int>(0,0)
    private var lastCommand: MTLCommandBuffer?
    private var lastWallTime: CFTimeInterval?
    private var frame = 0
    private var pausedSignature: SIMD4<Float>?
    private var accumulator: Float = 0
    private var particleVolume: Float = 0
    private let inFlight = DispatchSemaphore(value: 3)
    private let spacing: Float = 0.065
    private let timeStep: Float = 1.0 / 120

    init(device: MTLDevice, library: MTLLibrary? = nil) throws {
        self.device = device
        guard let queue = device.makeCommandQueue(), let library = library ?? device.makeDefaultLibrary() else {
            throw LabError.message("Metal could not load the fluid shaders.")
        }
        self.queue = queue
        self.library = library
        super.init()
        for name in ["labPredict","labClearHeads","labBuildGrid","labLambda","labDelta","labApply","labVelocity","labFinish","labSmoothDepth"] {
            guard let function = library.makeFunction(name: name) else { throw LabError.message("Missing shader: \(name)") }
            kernels[name] = try device.makeComputePipelineState(function: function)
        }
        depthPipeline = try pipeline(vertex: "labParticleVertex", fragment: "labParticleDepth", format: .r32Float, depth: true)
        thicknessPipeline = try pipeline(vertex: "labParticleVertex", fragment: "labParticleThickness", format: .rgba16Float, additive: true)
        composePipeline = try pipeline(vertex: "labFullscreen", fragment: "labCompose", format: .rgba16Float)
        glassPipeline = try pipeline(vertex: "labGlassVertex", fragment: "labGlassFragment", format: .bgra8Unorm_srgb, depth: true)
        copyPipeline = try pipeline(vertex: "labFullscreen", fragment: "labCopy", format: .bgra8Unorm_srgb, depth: true)
        let state = MTLDepthStencilDescriptor()
        state.depthCompareFunction = .lessEqual; state.isDepthWriteEnabled = true
        depthState = device.makeDepthStencilState(descriptor: state)
        profilesBuffer = makeBuffer(profiles.flatMap(\.radii))
        heads = device.makeBuffer(length: 64*48*32*MemoryLayout<Int32>.stride, options: .storageModePrivate)
        meshes = profiles.map { profile in
            let vertices = labGlassMesh(profile)
            return (makeBuffer(vertices), vertices.count)
        }
        reset()
    }

    private func pipeline(vertex: String, fragment: String, format: MTLPixelFormat,
                          depth: Bool = false, additive: Bool = false) throws -> MTLRenderPipelineState {
        let d = MTLRenderPipelineDescriptor()
        d.label = fragment
        d.vertexFunction = library.makeFunction(name: vertex)
        d.fragmentFunction = library.makeFunction(name: fragment)
        d.colorAttachments[0].pixelFormat = format
        if depth { d.depthAttachmentPixelFormat = .depth32Float }
        if additive {
            let a = d.colorAttachments[0]!
            a.isBlendingEnabled = true
            a.sourceRGBBlendFactor = .one; a.destinationRGBBlendFactor = .one
            a.sourceAlphaBlendFactor = .one; a.destinationAlphaBlendFactor = .one
        }
        return try device.makeRenderPipelineState(descriptor: d)
    }

    private func makeBuffer<T>(_ array: [T]) -> MTLBuffer {
        array.withUnsafeBytes { bytes in
            device.makeBuffer(bytes: bytes.baseAddress!, length: bytes.count, options: .storageModeShared)!
        }
    }

    func reset(twoColors: Bool = false) {
        lastCommand?.waitUntilCompleted()
        simulationTime = 0; pourTime = nil; accumulator = 0; lastWallTime = nil; paused = false
        var values: [LabParticle] = []
        let profile = profiles[0]
        let volume = profile.usableVolume * 0.75
        let height = profile.height(for: volume)
        let world = labVessels(time: nil, profiles: profiles)[0].world
        var y: Float = 0.055
        while y < height - 0.025 {
            let r = profile.radius(at: y) - 0.04
            var x = -r
            while x <= r {
                var z = -r
                while z <= r {
                    if x*x+z*z < r*r {
                        let position = world * SIMD4<Float>(x,y,z,1)
                        let p = SIMD4(position.xyz, 0)
                        let dye: Float = twoColors && y > height * 0.52 ? 1 : 0
                        values.append(LabParticle(position:p,predicted:p,velocity:SIMD4(0,0,0,dye)))
                    }
                    z += spacing
                }
                x += spacing
            }
            y += spacing
        }
        particleCount = values.count
        particleVolume = volume / Float(particleCount)
        particles = makeBuffer(values)
        next = device.makeBuffer(length: particleCount*4, options: .storageModePrivate)
        lambdas = device.makeBuffer(length: particleCount*4, options: .storageModePrivate)
        deltas = device.makeBuffer(length: particleCount*16, options: .storageModePrivate)
        velocities = device.makeBuffer(length: particleCount*16, options: .storageModePrivate)
    }

    func beginPour() { if pourTime == nil { pourTime = -max(0,1.5-simulationTime); paused = false } }
    var phase: String {
        guard let t = pourTime else { return "Ready to pour" }
        switch t {
        case ..<0: return "Settling the initial fill"
        case ..<1.4: return "Lifting into position"
        case ..<3.6: return "Positioning above the flask"
        case ..<6.4: return "Tilting toward the flask"
        case ..<10.5: return "Pouring"
        case ..<13.3: return "Stopping the stream"
        case ..<16.3: return "Returning to the tray"
        case ..<18.5: return "Settling"
        default: return "Pour complete"
        }
    }

    private func texture(_ format: MTLPixelFormat, width: Int, height: Int, usage: MTLTextureUsage) -> MTLTexture {
        let d = MTLTextureDescriptor.texture2DDescriptor(pixelFormat:format,width:width,height:height,mipmapped:false)
        d.storageMode = .private; d.usage = usage
        return device.makeTexture(descriptor:d)!
    }

    private func resize(width: Int, height: Int) {
        guard viewportSize != SIMD2(width,height) else { return }
        lastCommand?.waitUntilCompleted()
        viewportSize = SIMD2(width,height)
        depth = texture(.r32Float,width:width,height:height,usage:[.renderTarget,.shaderRead])
        smoothA = texture(.r32Float,width:width,height:height,usage:[.shaderRead,.shaderWrite])
        smoothB = texture(.r32Float,width:width,height:height,usage:[.shaderRead,.shaderWrite])
        depthTest = texture(.depth32Float,width:width,height:height,usage:.renderTarget)
        thickness = texture(.rgba16Float,width:width,height:height,usage:[.renderTarget,.shaderRead])
        scene = texture(.rgba16Float,width:width,height:height,usage:[.renderTarget,.shaderRead])
        glassDepth = texture(.depth32Float,width:width,height:height,usage:.renderTarget)
    }

    private func dispatch(_ name: String, count: Int, command: MTLCommandBuffer,
                          buffers: [(Int,MTLBuffer)], uniforms: LabUniforms? = nil,
                          vessels: [LabVesselUniform]? = nil) {
        let encoder = command.makeComputeCommandEncoder()!
        encoder.label = name
        let pipeline = kernels[name]!
        encoder.setComputePipelineState(pipeline)
        for (index,buffer) in buffers { encoder.setBuffer(buffer,offset:0,index:index) }
        if var u = uniforms { encoder.setBytes(&u,length:MemoryLayout<LabUniforms>.stride,index:1) }
        if let vessels { vessels.withUnsafeBytes { encoder.setBytes($0.baseAddress!,length:$0.count,index:2) } }
        encoder.dispatchThreads(MTLSize(width:count,height:1,depth:1),
            threadsPerThreadgroup:MTLSize(width:min(128,pipeline.maxTotalThreadsPerThreadgroup),height:1,depth:1))
        encoder.endEncoding()
    }

    private func simulate(command: MTLCommandBuffer, uniforms: LabUniforms, vessels: [LabVesselUniform]) {
        let n = particleCount
        dispatch("labPredict",count:n,command:command,buffers:[(0,particles),(3,profilesBuffer)],uniforms:uniforms,vessels:vessels)
        for _ in 0..<3 {
            dispatch("labClearHeads",count:64*48*32,command:command,buffers:[(0,heads)])
            dispatch("labBuildGrid",count:n,command:command,buffers:[(0,particles),(2,heads),(3,next)],uniforms:uniforms)
            dispatch("labLambda",count:n,command:command,buffers:[(0,particles),(2,heads),(3,next),(4,lambdas)],uniforms:uniforms)
            dispatch("labDelta",count:n,command:command,buffers:[(0,particles),(2,heads),(3,next),(4,lambdas),(5,deltas)],uniforms:uniforms)
            dispatch("labApply",count:n,command:command,buffers:[(0,particles),(3,profilesBuffer),(4,deltas)],uniforms:uniforms,vessels:vessels)
        }
        // Rebuild after the final corrections, before velocity smoothing.
        dispatch("labClearHeads",count:64*48*32,command:command,buffers:[(0,heads)])
        dispatch("labBuildGrid",count:n,command:command,buffers:[(0,particles),(2,heads),(3,next)],uniforms:uniforms)
        dispatch("labVelocity",count:n,command:command,buffers:[(0,particles),(2,velocities)],uniforms:uniforms)
        dispatch("labFinish",count:n,command:command,buffers:[(0,particles),(2,heads),(3,next),(4,velocities)],uniforms:uniforms)
    }

    private func pass(color: MTLTexture, clear: MTLClearColor = MTLClearColorMake(0,0,0,0), depth: MTLTexture? = nil) -> MTLRenderPassDescriptor {
        let d = MTLRenderPassDescriptor()
        d.colorAttachments[0].texture=color; d.colorAttachments[0].loadAction = .clear
        d.colorAttachments[0].storeAction = .store; d.colorAttachments[0].clearColor=clear
        if let depth {
            d.depthAttachment.texture=depth; d.depthAttachment.loadAction = .clear
            d.depthAttachment.storeAction = .dontCare; d.depthAttachment.clearDepth=1
        }
        return d
    }

    /// Same path is used by the interactive view and the offscreen validation tool.
    @discardableResult
    func encodeFrame(target: MTLTexture, deltaTime: Float, present: CAMetalDrawable? = nil, completion: MTLCommandBufferHandler? = nil) -> MTLCommandBuffer {
        resize(width:target.width,height:target.height)
        let command = queue.makeCommandBuffer()!
        command.label = "Fluid Lab frame"
        let (vp,view,eye) = labCamera(aspect:Float(target.width)/Float(target.height), azimuth:orbit)
        var u = LabUniforms(viewProjection:vp,inverseViewProjection:vp.inverse,view:view,camera:SIMD4(eye,1),
            viewport:SIMD4(Float(target.width),Float(target.height),pointMode ? spacing*0.30 : spacing*0.88,simulationTime),
            physics:SIMD4(timeStep,spacing*2.3,particleVolume,viscosity),options:SIMD4(UInt32(particleCount),pointMode ? 1:0,0,0))
        if !paused {
            accumulator += min(max(deltaTime,0),1.0/20)
            var steps = 0
            while accumulator >= timeStep && steps < 6 {
                simulationTime += timeStep
                if pourTime != nil { pourTime! += timeStep }
                let vessels = labVessels(time:pourTime,profiles:profiles,horizontalOffset:aimOffset)
                var stepUniforms=u
                stepUniforms.viewport.w=simulationTime
                if simulationTime < 1 { stepUniforms.physics.w=max(viscosity,0.35) }
                simulate(command:command,uniforms:stepUniforms,vessels:vessels)
                accumulator -= timeStep; steps += 1
            }
        }
        u.viewport.w = simulationTime
        let vessels = labVessels(time:pourTime,profiles:profiles,horizontalOffset:aimOffset)
        let depthEncoder = command.makeRenderCommandEncoder(descriptor:pass(color:depth,clear:MTLClearColorMake(1,1,1,1),depth:depthTest))!
        depthEncoder.label = "Particle surface depth"
        depthEncoder.setRenderPipelineState(depthPipeline); depthEncoder.setDepthStencilState(depthState)
        depthEncoder.setVertexBuffer(particles,offset:0,index:0)
        depthEncoder.setVertexBytes(&u,length:MemoryLayout<LabUniforms>.stride,index:1)
        depthEncoder.setFragmentBytes(&u,length:MemoryLayout<LabUniforms>.stride,index:1)
        vessels.withUnsafeBytes { depthEncoder.setFragmentBytes($0.baseAddress!,length:$0.count,index:2) }
        depthEncoder.setFragmentBuffer(profilesBuffer,offset:0,index:3)
        depthEncoder.drawPrimitives(type:.triangle,vertexStart:0,vertexCount:6,instanceCount:particleCount)
        depthEncoder.endEncoding()
        let thicknessEncoder = command.makeRenderCommandEncoder(descriptor:pass(color:thickness))!
        thicknessEncoder.label = "Liquid optical thickness"
        thicknessEncoder.setRenderPipelineState(thicknessPipeline)
        thicknessEncoder.setVertexBuffer(particles,offset:0,index:0)
        thicknessEncoder.setVertexBytes(&u,length:MemoryLayout<LabUniforms>.stride,index:1)
        thicknessEncoder.setFragmentBytes(&u,length:MemoryLayout<LabUniforms>.stride,index:1)
        thicknessEncoder.drawPrimitives(type:.triangle,vertexStart:0,vertexCount:6,instanceCount:particleCount)
        thicknessEncoder.endEncoding()
        if !pointMode {
            for (input,output,direction) in [(depth!,smoothA!,SIMD2<UInt32>(1,0)),(smoothA!,smoothB!,SIMD2<UInt32>(0,1)),(smoothB!,smoothA!,SIMD2<UInt32>(1,0)),(smoothA!,smoothB!,SIMD2<UInt32>(0,1))] {
                let e=command.makeComputeCommandEncoder()!
                e.setComputePipelineState(kernels["labSmoothDepth"]!)
                e.setTexture(input,index:0); e.setTexture(output,index:1)
                var direction=direction
                e.setBytes(&direction,length:MemoryLayout<SIMD2<UInt32>>.stride,index:0)
                e.dispatchThreads(MTLSize(width:target.width,height:target.height,depth:1),threadsPerThreadgroup:MTLSize(width:16,height:16,depth:1))
                e.endEncoding()
            }
        }
        let compose=command.makeRenderCommandEncoder(descriptor:pass(color:scene))!
        compose.label = "Reconstruct and shade liquid"
        compose.setRenderPipelineState(composePipeline)
        compose.setFragmentBytes(&u,length:MemoryLayout<LabUniforms>.stride,index:0)
        compose.setFragmentTexture(pointMode ? depth : smoothB,index:0)
        compose.setFragmentTexture(thickness,index:1)
        compose.drawPrimitives(type:.triangle,vertexStart:0,vertexCount:3)
        compose.endEncoding()
        let final=command.makeRenderCommandEncoder(descriptor:pass(color:target,depth:glassDepth))!
        final.label = "Glass vessels and graduations"
        final.setRenderPipelineState(copyPipeline)
        final.setFragmentTexture(scene,index:0)
        final.drawPrimitives(type:.triangle,vertexStart:0,vertexCount:3)
        final.setRenderPipelineState(glassPipeline); final.setDepthStencilState(depthState)
        final.setCullMode(.none)
        final.setVertexBytes(&u,length:MemoryLayout<LabUniforms>.stride,index:1)
        final.setFragmentBytes(&u,length:MemoryLayout<LabUniforms>.stride,index:1)
        for i in 0..<2 {
            var vessel=vessels[i]
            final.setVertexBuffer(meshes[i].0,offset:0,index:0)
            final.setVertexBytes(&vessel,length:MemoryLayout<LabVesselUniform>.stride,index:2)
            final.setFragmentBytes(&vessel,length:MemoryLayout<LabVesselUniform>.stride,index:2)
            final.drawPrimitives(type:.triangle,vertexStart:0,vertexCount:meshes[i].1)
        }
        final.endEncoding()
        if let present { command.present(present) }
        lastCommand=command
        if let completion { command.addCompletedHandler(completion) }
        command.commit()
        frame += 1
        return command
    }

    /// Explicit readback used by the offscreen validator, never by rendering.
    func particleSamples() -> [LabParticle] {
        lastCommand?.waitUntilCompleted()
        return Array(UnsafeBufferPointer(start:particles.contents().bindMemory(to:LabParticle.self,capacity:particleCount),count:particleCount))
    }

    func snapshot(wait: Bool = true) -> LabFrameStats {
        if wait { lastCommand?.waitUntilCompleted() }
        guard lastCommand == nil || lastCommand?.status == .completed else { return LabFrameStats() }
        let p=particles.contents().bindMemory(to:LabParticle.self,capacity:particleCount)
        var stats=LabFrameStats()
        for i in 0..<particleCount {
            let a=p[i]
            if !a.position.x.isFinite || !a.position.y.isFinite || !a.position.z.isFinite { stats.nonFinite += 1; continue }
            if a.position.w == 0 { stats.source += 1 }
            else if a.position.w == 1 { stats.destination += 1 }
            else if a.position.y <= 0.08 { stats.spilled += 1 }
            else { stats.airborne += 1 }
            stats.maximumSpeed=max(stats.maximumSpeed,simd_length(a.velocity.xyz))
        }
        if let lastCommand, lastCommand.gpuEndTime > lastCommand.gpuStartTime {
            stats.gpuMilliseconds=(lastCommand.gpuEndTime-lastCommand.gpuStartTime)*1000
        }
        return stats
    }

    nonisolated func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {}
    nonisolated func draw(in view: MTKView) {
        MainActor.assumeIsolated {
            guard inFlight.wait(timeout:.now()) == .success else { return }
            let bounds=view.bounds.size
            if bounds.width > 0 && bounds.height > 0 {
                let scale=min(1.5,1000/max(bounds.width,bounds.height))
                let desired=CGSize(width:max(1,Int(bounds.width*scale)),height:max(1,Int(bounds.height*scale)))
                if view.drawableSize != desired { view.drawableSize=desired }
            }
            if lastCommand?.status == .error {
                onError?(lastCommand?.error?.localizedDescription ?? "The GPU could not complete a frame.")
                view.isPaused=true
                inFlight.signal()
                return
            }
            if paused {
                let signature=SIMD4<Float>(Float(view.drawableSize.width),Float(view.drawableSize.height),orbit,pointMode ? 1:0)
                if pausedSignature == signature { inFlight.signal(); return }
                pausedSignature=signature
            } else { pausedSignature=nil }
            guard let drawable=view.currentDrawable else { inFlight.signal(); return }
            if frame % 30 == 0, lastCommand?.status == .completed {
                onUpdate?(snapshot(wait:false),phase,pourTime ?? 0)
            }
            let now=CACurrentMediaTime()
            let delta=Float(lastWallTime.map { now-$0 } ?? 1.0/60)
            lastWallTime=now
            let semaphore=inFlight
            encodeFrame(target:drawable.texture,deltaTime:delta,present:drawable) { _ in
                semaphore.signal()
            }
        }
    }
}

enum LabError: LocalizedError {
    case message(String)
    var errorDescription: String? { if case let .message(text)=self { text } else { "Metal error" } }
}
