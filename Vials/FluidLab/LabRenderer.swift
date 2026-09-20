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
    var meterLookahead: Float = 0.34
    var playbackSpeed: Float = 1
    private(set) var tilt: Float = 0
    private(set) var cutoffTime: Float?
    private(set) var returnStart: Float?
    private var cutoffTilt: Float = 0
    private var previousWorlds: [simd_float4x4] = []
    private var measuredLoss: Float = 0
    private var flowRate: Float = 0
    private var feedbackTime: Float = 0
    private(set) var ledger = LabTransferLedger()
    private(set) var transferAccepted = false
    private(set) var completed = false
    private(set) var cleanupTime: Float?
    private(set) var cleanupParticleCount = 0
    private(set) var unitsBeforeCleanup: Float = 0
    private(set) var spillBeforeCleanup = 0
    var targetParticleCount: Int { Int((Float(particleCount)/3).rounded()) }
    var transferredUnits: Float { measuredLoss }
    var resting: Bool { completed || (pourTime == nil && simulationTime >= 4) }
    var currentVessels: [LabVesselUniform] {
        labVessels(time:pourTime,profiles:profiles,horizontalOffset:aimOffset,tilt:tilt,
                   returnTime:returnStart.map { max(0,(pourTime ?? 0)-$0) },
                   cutoffTilt:cutoffTime == nil ? nil:cutoffTilt,cutoffElapsed:(pourTime ?? 0)-(cutoffTime ?? 0))
    }
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
        heads = device.makeBuffer(length: 128*48*40*MemoryLayout<Int32>.stride, options: .storageModePrivate)
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
        previousWorlds=[]
        tilt=0; cutoffTime=nil; returnStart=nil; cutoffTilt=0
        measuredLoss=0; flowRate=0; feedbackTime=0; completed=false
        ledger=LabTransferLedger(); transferAccepted=false; pausedSignature=nil
        cleanupTime=nil; cleanupParticleCount=0; unitsBeforeCleanup=0; spillBeforeCleanup=0
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
        guard let t=pourTime else { return "Ready to pour one unit" }
        if completed { return transferAccepted ? "One unit transferred" : "Pour needs adjustment" }
        if cleanupTime != nil { return "Final settling" }
        if let start=returnStart { return t-start < 1.4 ? "Returning to the tray" : "Settling" }
        if cutoffTime != nil { return "Stopping the stream" }
        if t < 0 { return "Settling the initial fill" }
        if t < 1.4 { return "Lifting into position" }
        if t < 2.6 { return "Positioning above the flask" }
        return measuredLoss > 0.01 ? "Measuring one unit" : "Tilting toward the flask"
    }

    /// One bounded readback per rendered frame during a transfer. This prototype
    /// serializes that frame with the preceding GPU command to avoid racing shared
    /// particle memory. A GPU-resident controller is the later optimization path.
    private func updateMeter() {
        guard let t=pourTime, !completed else { return }
        let stats=snapshot()
        let lost=Float(particleCount-stats.source)/Float(particleCount)*3
        let dt=max(simulationTime-feedbackTime,0.0001)
        let instantaneous=max(0,(lost-measuredLoss)/dt)
        flowRate += (instantaneous-flowRate)*min(1,dt*10)
        measuredLoss=lost; feedbackTime=simulationTime
        if t >= 2.6, cutoffTime == nil, lost+flowRate*meterLookahead >= 0.99 {
            cutoffTime=t; cutoffTilt=tilt
        }
        if let cleanup=cleanupTime {
            if t-cleanup >= 0.8 {
                completed=true
                transferAccepted=stats.destination == targetParticleCount && stats.source == particleCount-targetParticleCount && stats.spilled == 0 && stats.airborne == 0
                if transferAccepted { ledger.commitOneUnit() }
            }
        } else if let start=returnStart, t-start > 2.9 {
            unitsBeforeCleanup=Float(stats.destination)/Float(particleCount)*3
            spillBeforeCleanup=stats.spilled+stats.airborne
            // The user-approved visual correction is bounded to 5% of ONE unit,
            // both at source and receiver, including any escaped particles.
            let allowed=max(1,Int(Float(targetParticleCount)*0.05))
            let donorMoves=max(0,stats.source-(particleCount-targetParticleCount))+max(0,stats.destination-targetParticleCount)+stats.spilled+stats.airborne
            if abs(unitsBeforeCleanup-1) <= 0.05 && abs(lost-1) <= 0.05 && donorMoves <= allowed && stats.nonFinite == 0 {
                applyFinalCorrection(stats:stats)
                cleanupTime=t
            } else { completed=true; transferAccepted=false }
        }
    }

    /// A deliberately small presentation cleanup, not part of the physical solver.
    /// Move only surplus particles; preserve count, per-particle volume and dye tags.
    /// The recipient splats fade in and the solver relaxes them before committing.
    private func applyFinalCorrection(stats:LabFrameStats) {
        let p=particles.contents().bindMemory(to:LabParticle.self,capacity:particleCount)
        let targets=[particleCount-targetParticleCount,targetParticleCount]
        var groups=[[Int](),[Int]()]
        var donors:[Int]=[]
        for i in 0..<particleCount {
            let owner=Int(p[i].position.w.rounded())
            if owner >= 0 && owner < 2 { groups[owner].append(i) } else { donors.append(i) }
        }
        for owner in 0..<2 {
            groups[owner].sort { p[$0].position.y < p[$1].position.y }
            while groups[owner].count > targets[owner] { donors.append(groups[owner].removeLast()) }
        }
        cleanupParticleCount=donors.count
        let vessels=currentVessels
        for owner in 0..<2 {
            let needed=targets[owner]-groups[owner].count
            guard needed > 0 else { continue }
            let vessel=vessels[owner], profile=profiles[owner]
            let top=groups[owner].suffix(max(1,groups[owner].count/15))
            let meanHeight=top.reduce(Float(0)) { $0+(vessel.inverseWorld*SIMD4(p[$1].position.xyz,1)).y }/Float(max(1,top.count))
            let y=min(profile.height-0.18,max(0.065,meanHeight+spacing*0.7))
            let radius=max(0.02,profile.radius(at:y)-spacing*1.5)
            for n in 0..<needed {
                let i=donors.removeLast()
                let a=Float(n)*2.3999632
                let r=radius*sqrt((Float(n)+0.5)/Float(needed))
                let world=vessel.world*SIMD4<Float>(r*cos(a),y,r*sin(a),1)
                let point=SIMD4(world.xyz,Float(owner))
                p[i].position=point; p[i].predicted=point
                p[i].velocity=SIMD4(0,0,0,p[i].velocity.w)
                p[i].visual=SIMD4(simulationTime,0,0,0)
            }
        }
        assert(donors.isEmpty)
    }

    private func advancePose() {
        guard let t=pourTime, !completed else { return }
        if let stop=cutoffTime {
            let elapsed=t-stop
            if elapsed < 0.8 { tilt=cutoffTilt-min(0.45,cutoffTilt)*labSmooth(elapsed/0.8) }
            else { tilt=max(0,cutoffTilt-0.45)*(1-labSmooth((elapsed-0.8)/1.6)) }
            if elapsed >= 2.4, returnStart == nil { returnStart=t }
        } else if t >= 2.6 {
            // Approach slowly once a stream exists; loss includes liquid in flight.
            let rate: Float = measuredLoss < 0.05 ? 0.40 : (measuredLoss < 0.65 ? 0.08:0.025)
            tilt=min(1.52,tilt+rate*timeStep)
            if t > 20 { cutoffTime=t; cutoffTilt=tilt }
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
            dispatch("labClearHeads",count:128*48*40,command:command,buffers:[(0,heads)])
            dispatch("labBuildGrid",count:n,command:command,buffers:[(0,particles),(2,heads),(3,next)],uniforms:uniforms)
            dispatch("labLambda",count:n,command:command,buffers:[(0,particles),(2,heads),(3,next),(4,lambdas)],uniforms:uniforms)
            dispatch("labDelta",count:n,command:command,buffers:[(0,particles),(2,heads),(3,next),(4,lambdas),(5,deltas)],uniforms:uniforms)
            dispatch("labApply",count:n,command:command,buffers:[(0,particles),(3,profilesBuffer),(4,deltas)],uniforms:uniforms,vessels:vessels)
        }
        // Rebuild after the final corrections, before velocity smoothing.
        dispatch("labClearHeads",count:128*48*40,command:command,buffers:[(0,heads)])
        dispatch("labBuildGrid",count:n,command:command,buffers:[(0,particles),(2,heads),(3,next)],uniforms:uniforms)
        dispatch("labVelocity",count:n,command:command,buffers:[(0,particles),(4,velocities),(3,profilesBuffer)],uniforms:uniforms,vessels:vessels)
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
        if pourTime != nil && !paused { updateMeter() }
        resize(width:target.width,height:target.height)
        let command = queue.makeCommandBuffer()!
        command.label = "Fluid Lab frame"
        let (vp,view,eye) = labCamera(aspect:Float(target.width)/Float(target.height), azimuth:orbit)
        var u = LabUniforms(viewProjection:vp,inverseViewProjection:vp.inverse,view:view,camera:SIMD4(eye,1),
            viewport:SIMD4(Float(target.width),Float(target.height),pointMode ? spacing*0.30 : spacing*0.88,simulationTime),
            physics:SIMD4(timeStep,spacing*2.3,particleVolume,viscosity),options:SIMD4(UInt32(particleCount),pointMode ? 1:0,0,0))
        if !paused && !resting {
            accumulator += min(max(deltaTime,0),1.0/20)*playbackSpeed
            var steps = 0
            while accumulator >= timeStep && steps < 6 {
                simulationTime += timeStep
                if pourTime != nil { pourTime! += timeStep }; advancePose()
                var vessels = currentVessels
                for i in vessels.indices {
                    if previousWorlds.count == vessels.count { vessels[i].previousWorld=previousWorlds[i] }
                }
                previousWorlds=vessels.map(\.world)
                var stepUniforms=u
                stepUniforms.viewport.w=simulationTime
                if simulationTime < 1 { stepUniforms.physics.w=max(viscosity,0.35) }
                simulate(command:command,uniforms:stepUniforms,vessels:vessels)
                accumulator -= timeStep; steps += 1
            }
        }
        u.viewport.w = simulationTime
        let vessels = currentVessels
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
        let shadows=LabContactShadow.floorSamples(vessels:vessels,profiles:profiles)
        shadows.withUnsafeBytes { compose.setFragmentBytes($0.baseAddress!,length:$0.count,index:1) }
        compose.setFragmentTexture(pointMode ? depth : smoothB,index:0)
        compose.setFragmentTexture(thickness,index:1)
        compose.setFragmentTexture(thickness,index:2) // unused identity texture in legacy mode
        compose.setFragmentTexture(thickness,index:3) // unused density pattern in legacy mode
        var patternMotion=SIMD4<Float>.zero
        compose.setFragmentBytes(&patternMotion,length:MemoryLayout<SIMD4<Float>>.stride,index:3)
        vessels.withUnsafeBytes { compose.setFragmentBytes($0.baseAddress!,length:$0.count,index:2) }
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
            if paused || resting {
                let signature=SIMD4<Float>(Float(view.drawableSize.width),Float(view.drawableSize.height),orbit,pointMode ? 1:0)
                if pausedSignature == signature { inFlight.signal(); return }
                pausedSignature=signature
                if lastCommand?.status == .completed { onUpdate?(snapshot(wait:false),phase,pourTime ?? 0) }
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
