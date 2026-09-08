import Foundation
import MetalKit
import simd

struct LabBoardMetrics {
    var guided=0
    var arrived=0
    var departed=0
    var outside=0
    var wrongParcel=0
    var nonFinite=0
    var gpuMilliseconds:Double=0
}

@MainActor
final class LabBoardRenderer: NSObject, MTKViewDelegate {
    let device:MTLDevice
    let profiles=LabBoardLayout.profiles()
    let queue:MTLCommandQueue
    let library:MTLLibrary
    static let particlesPerUnit=640
    private(set) var game=LabBoardGame()
    private(set) var particleCount=0
    private(set) var simulationTime:Float=0
    private(set) var pourTime:Float?
    private(set) var tilt:Float=0
    private(set) var cutoffTime:Float?
    private var cutoffTilt:Float=0
    private var returnStart:Float?
    private var cleanupStart:Float?
    private var previousWorlds:[simd_float4x4]=[]
    private var beforeParticles:[LabParticle]=[]
    private var historyParticles:[[LabParticle]]=[]
    private(set) var lastMetrics=LabBoardMetrics()
    private(set) var correctionCount=0
    private(set) var arrivalBeforeCorrection:Float=0
    private(set) var lastOutcome=""
    private var layerBands:[LabBoardBand]=[]
    var funnelEnabled=true
    var paused=false
    var pointMode=false
    var orbit:Float=0.12
    var playbackSpeed:Float=1
    var viscosity:Float=0.10
    var onFrame:((Double,Double,Double)->Void)?
    var onError:((String)->Void)?
    var onUpdate:((LabBoardMetrics,String,Float)->Void)?
    var resting:Bool { game.pending == nil }
    var currentVessels:[LabVesselUniform] {
        LabBoardLayout.vessels(profiles:profiles,move:game.pending,time:pourTime ?? 0,tilt:tilt,
            cutoffTilt:cutoffTime == nil ? nil:cutoffTilt,cutoffElapsed:(pourTime ?? 0)-(cutoffTime ?? 0),
            returnElapsed:returnStart.map { (pourTime ?? 0)-$0 })
    }
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
    private var frontDye: MTLTexture!
    private var dyeA: MTLTexture!
    private var dyeB: MTLTexture!
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
    private let spacing: Float = 0.079
    private let timeStep: Float = 1.0 / 120

    init(device: MTLDevice, library: MTLLibrary? = nil) throws {
        self.device = device
        guard let queue = device.makeCommandQueue(), let library = library ?? device.makeDefaultLibrary() else {
            throw LabError.message("Metal could not load the fluid shaders.")
        }
        self.queue = queue
        self.library = library
        super.init()
        for name in ["labPredict","labClearHeads","labBuildGrid","labLambda","labDelta","labApply","labVelocity","labFinish","labSmoothDepth","labBoardSmoothDepth","labSmoothDye","labBoardConstrain"] {
            guard let function = library.makeFunction(name: name) else { throw LabError.message("Missing shader: \(name)") }
            kernels[name] = try device.makeComputePipelineState(function: function)
        }
        depthPipeline = try pipeline(vertex: "labParticleVertex", fragment: "labBoardParticleDepth", format: .r32Float, depth: true)
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
        if fragment == "labBoardParticleDepth" { d.colorAttachments[1].pixelFormat = .r16Float }
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

    private func clearMotion() {
        pourTime=nil;tilt=0;cutoffTime=nil;returnStart=nil;cleanupStart=nil
        previousWorlds=[];accumulator=0;lastWallTime=nil;pausedSignature=nil
        correctionCount=0;arrivalBeforeCorrection=0;lastMetrics=LabBoardMetrics();paused=false
    }
    func reset(state:LabBoardState = .firstSort) {
        lastCommand?.waitUntilCompleted()
        game=LabBoardGame(state:state);simulationTime=0;clearMotion();historyParticles=[];beforeParticles=[];lastOutcome=""
        let values=seed(state:state)
        particleCount=values.count;particleVolume=profiles[0].usableVolume/4/Float(Self.particlesPerUnit)
        particles=makeBuffer(values)
        next=device.makeBuffer(length:particleCount*4,options:.storageModePrivate)
        lambdas=device.makeBuffer(length:particleCount*4,options:.storageModePrivate)
        deltas=device.makeBuffer(length:particleCount*16,options:.storageModePrivate)
        velocities=device.makeBuffer(length:particleCount*16,options:.storageModePrivate)
    }
    /// Install the shared puzzle checkpoint when changing presentation or undoing.
    /// Particle snapshots are retained within this session; classic-only moves
    /// are reconstructed from exact unit volumes on the next Fluid presentation.
    func install(game:LabBoardGame,samples:[LabParticle]? = nil) {
        precondition(game.pending == nil)
        reset(state:game.state)
        self.game=game
        if let samples, samples.count==particleCount { particles=makeBuffer(samples) }
    }

    private func radical(_ index:Int,_ base:Int) -> Float {
        var n=index,f:Float=1,result:Float=0
        while n>0 { f/=Float(base);result+=f*Float(n%base);n/=base }
        return result
    }
    private func seed(state:LabBoardState) -> [LabParticle] {
        var values:[LabParticle]=[]
        for owner in state.stacks.indices {
            let profile=profiles[owner],world=labTranslation(LabBoardLayout.homes[owner]),unit=profile.usableVolume/4
            for (layer,parcel) in state.stacks[owner].enumerated() {
                for i in 0..<Self.particlesPerUnit {
                    let v=(Float(layer)+(Float(i)+0.5)/Float(Self.particlesPerUnit))*unit
                    let y=max(0.04,profile.height(for:v))
                    let r=max(0.01,profile.radius(at:y)-0.042)*sqrt(radical(i+1,2))
                    let a=radical(i+1,3)*2*Float.pi
                    let p=SIMD4((world*SIMD4<Float>(r*cos(a),y,r*sin(a),1)).xyz,Float(owner))
                    values.append(LabParticle(position:p,predicted:p,velocity:SIMD4(0,0,0,Float(state.colors[parcel])),visual:SIMD4(0,Float(parcel),0,0)))
                }
            }
        }
        return values
    }
    @discardableResult func begin(from:Int,to:Int) -> Bool {
        guard game.pending == nil,game.state.move(from:from,to:to) != nil else { return false }
        lastCommand?.waitUntilCompleted()
        beforeParticles=particleSamples()
        clearMotion();lastOutcome=""
        guard let move=game.begin(from:from,to:to) else { return false }
        let ids=Set(move.parcels)
        let p=particles.contents().bindMemory(to:LabParticle.self,capacity:particleCount)
        for i in 0..<particleCount { p[i].visual.w=0; p[i].visual.z=ids.contains(Int(p[i].visual.y)) ? 1:0; p[i].velocity=SIMD4(0,0,0,p[i].velocity.w) }
        pourTime = -LabBoardTiming.preparation // settle the newly active pair before moving it
        return true
    }
    @discardableResult func undo() -> Bool {
        guard game.pending == nil,!historyParticles.isEmpty else { return false }
        lastCommand?.waitUntilCompleted()
        guard game.undo() else { return false }
        particles=makeBuffer(historyParticles.removeLast());clearMotion();lastOutcome="Move undone"
        return true
    }
    var phase:String {
        if game.state.solved { return "Sorted beautifully" }
        guard let t=pourTime,let move=game.pending else { return lastOutcome.isEmpty ? "Choose a vial":lastOutcome }
        if cleanupStart != nil { return "Final settling" }
        if let start=returnStart { return t-start<LabBoardTiming.returned ? "Returning the vial":"Settling the layers" }
        if cutoffTime != nil { return "Stopping the stream" }
        if t<0 { return "Preparing the pour" }
        if t<LabBoardTiming.lift { return "Lifting the vial" }
        if t<LabBoardTiming.tiltStart { return "Moving into position" }
        return "Pouring \(move.amount) \(move.amount == 1 ? "unit":"units")"
    }
    private func advancePose() {
        guard let t=pourTime,game.pending != nil else { return }
        if let stop=cutoffTime {
            let elapsed=t-stop
            if elapsed<LabBoardTiming.stop { tilt=cutoffTilt-min(0.45,cutoffTilt)*labSmooth(elapsed/LabBoardTiming.stop) }
            else { tilt=max(0,cutoffTilt-0.45)*(1-labSmooth((elapsed-LabBoardTiming.stop)/LabBoardTiming.upright)) }
            if elapsed>=LabBoardTiming.untilted,returnStart == nil { returnStart=t }
        } else if t>=LabBoardTiming.tiltStart {
            let rate:Float=lastMetrics.departed<20 ? LabBoardTiming.approachRate:LabBoardTiming.pouringRate
            tilt=min(2.15,tilt+rate*timeStep)
            if t>LabBoardTiming.timeout { cutoffTime=t;cutoffTilt=tilt }
        }
    }
    private func updateTransfer() {
        guard let move=game.pending,let t=pourTime else { return }
        lastMetrics=measure()
        let target=move.amount*Self.particlesPerUnit
        if cutoffTime == nil,lastMetrics.departed>=Int(Float(target)*0.99),lastMetrics.arrived>=Int(Float(target)*0.955) {
            cutoffTime=t;cutoffTilt=tilt
        }
        if let cleanup=cleanupStart {
            if t-cleanup>=LabBoardTiming.cleanup {
                let samples=particleSamples()
                if let after=game.state.applying(move),inventoryMatches(samples,state:after) {
                    normalizeOrder(state:after)
                    historyParticles.append(beforeParticles)
                    _=game.commit(move);lastOutcome="Move complete"
                } else { rollback(message:"That pour needs another try") }
                pourTime=nil;tilt=0;previousWorlds=[];pausedSignature=nil
            }
        } else if let back=returnStart,t-back>LabBoardTiming.returned+LabBoardTiming.settling {
            let missing=target-lastMetrics.arrived
            arrivalBeforeCorrection=Float(lastMetrics.arrived)/Float(target)
            if missing>=0,missing<=Int(Float(target)*0.05),lastMetrics.wrongParcel==0,lastMetrics.nonFinite==0 {
                correct(move:move);cleanupStart=t
            } else { rollback(message:"Too much spilled · Try again") }
        }
        // Publish the transaction before idle rendering stops. Waiting for a
        // later GPU-completed draw can leave the controls stuck on "settling".
        if game.pending == nil { onUpdate?(lastMetrics,phase,pourTime ?? 0) }
    }
    private func rollback(message:String) {
        particles=makeBuffer(beforeParticles);game.cancel();pourTime=nil;tilt=0;previousWorlds=[];pausedSignature=nil;lastOutcome=message
    }
    private func inventoryMatches(_ samples:[LabParticle],state:LabBoardState) -> Bool {
        var owners=[Int](repeating:-1,count:state.colors.count),counts=[Int](repeating:0,count:state.colors.count)
        for (owner,stack) in state.stacks.enumerated() { for id in stack { owners[id]=owner } }
        for p in samples {
            let id=Int(p.visual.y)
            if !owners.indices.contains(id) || Int(p.position.w) != owners[id] || Int(p.velocity.w) != state.colors[id] { return false }
            counts[id]+=1
        }
        return counts.allSatisfy { $0 == Self.particlesPerUnit }
    }
    private func correct(move:LabBoardMove) {
        let p=particles.contents().bindMemory(to:LabParticle.self,capacity:particleCount)
        let ids=Set(move.parcels)
        let missing=(0..<particleCount).filter { ids.contains(Int(p[$0].visual.y)) && Int(p[$0].position.w) != move.destination }
        correctionCount=missing.count
        let profile=profiles[move.destination]
        let targetHeight=profile.height(for:profile.usableVolume*Float(game.state.stacks[move.destination].count+move.amount)/4)
        for (n,i) in missing.enumerated() {
            let y=max(0.055,targetHeight-0.06)
            let radius=max(0.02,profile.radius(at:y)-0.10)*sqrt((Float(n)+0.5)/Float(max(1,missing.count)))
            let a=Float(n)*2.3999632
            let world=LabBoardLayout.homes[move.destination]+SIMD3(radius*cos(a),y,radius*sin(a))
            let point=SIMD4(world,Float(move.destination))
            p[i].position=point;p[i].predicted=point;p[i].velocity=SIMD4(0,0,0,p[i].velocity.w);p[i].visual.x=simulationTime
        }
    }
    private func normalizeOrder(state:LabBoardState) {
        // Same-colored parcels may mingle. Reassign their unit IDs by height,
        // without moving particles or changing any color, for future partial runs.
        let p=particles.contents().bindMemory(to:LabParticle.self,capacity:particleCount)
        for (owner,stack) in state.stacks.enumerated() {
            var start=0
            while start<stack.count {
                var end=start+1
                while end<stack.count && state.colors[stack[end]] == state.colors[stack[start]] { end+=1 }
                let ids=Set(stack[start..<end])
                let indices=(0..<particleCount).filter { Int(p[$0].position.w)==owner && ids.contains(Int(p[$0].visual.y)) }.sorted { p[$0].position.y<p[$1].position.y }
                for (n,i) in indices.enumerated() { p[i].visual.y=Float(stack[start+n/Self.particlesPerUnit]);p[i].visual.z=0;p[i].visual.x=0 }
                start=end
            }
        }
    }
    private func makeBands() -> [LabBoardBand] {
        let count=game.state.colors.count
        var result=[LabBoardBand](repeating:LabBoardBand(range:SIMD4(-100,100,0,0)),count:count*4)
        let move=game.pending, selected=Set(move?.parcels ?? [])
        let after=cleanupStart == nil ? nil:move.flatMap { game.state.applying($0) }
        let state=after ?? game.state
        for (owner,stack) in state.stacks.enumerated() {
            let profile=profiles[owner]
            var levels:[Float]=[-100]
            for layer in 1...max(1,stack.count) { levels.append(profile.height(for:profile.usableVolume*Float(layer)/4)) }
            for (layer,id) in stack.enumerated() {
                let isMoving=selected.contains(id) && cleanupStart == nil
                var first=layer,last=layer+1
                if !isMoving {
                    while first>0 && state.colors[stack[first-1]] == state.colors[id] && !(cleanupStart == nil && selected.contains(stack[first-1])) { first-=1 }
                    while last<stack.count && state.colors[stack[last]] == state.colors[id] && !(cleanupStart == nil && selected.contains(stack[last])) { last+=1 }
                }
                let lower=isMoving && owner == move?.source ? levels[max(0,stack.count-(move?.amount ?? 0))]:levels[first]
                let upper:Float=isMoving || (last==stack.count && cleanupStart != nil) ? 100:levels[last]
                result[owner*count+id]=LabBoardBand(range:SIMD4(lower,upper,1,1))
            }
        }
        if let move,cleanupStart == nil {
            let profile=profiles[move.destination]
            let lower=game.state.stacks[move.destination].isEmpty ? -100:profile.height(for:profile.usableVolume*Float(game.state.stacks[move.destination].count)/4)
            for id in selected { result[move.destination*count+id]=LabBoardBand(range:SIMD4(lower,100,1,1)) }
        }
        return result
    }
    func measure() -> LabBoardMetrics {
        lastCommand?.waitUntilCompleted()
        var result=LabBoardMetrics()
        let p=particles.contents().bindMemory(to:LabParticle.self,capacity:particleCount)
        var originalOwners=[Int](repeating:-1,count:game.state.colors.count)
        for (owner,stack) in game.state.stacks.enumerated() { for id in stack { originalOwners[id]=owner } }
        let selected=Set(game.pending?.parcels ?? [])
        for i in 0..<particleCount {
            let a=p[i]
            guard [a.position.x,a.position.y,a.position.z,a.position.w,a.visual.y,a.velocity.w].allSatisfy(\.isFinite) else { result.nonFinite+=1;continue }
            let id=Int(a.visual.y),owner=Int(a.position.w)
            if owner<0 { result.outside+=1 }
            if selected.contains(id),let move=game.pending {
                if a.visual.w>0.5 { result.guided+=1 }
                if owner==move.destination { result.arrived+=1 }
                if owner != move.source { result.departed+=1 }
            } else if originalOwners.indices.contains(id),owner != originalOwners[id] { result.wrongParcel+=1 }
        }
        if let lastCommand,lastCommand.gpuEndTime>lastCommand.gpuStartTime { result.gpuMilliseconds=(lastCommand.gpuEndTime-lastCommand.gpuStartTime)*1000 }
        return result
    }

    private func constrainLayers(command:MTLCommandBuffer,uniforms:LabUniforms,vessels:[LabVesselUniform]) {
        let e=command.makeComputeCommandEncoder()!
        e.setComputePipelineState(kernels["labBoardConstrain"]!)
        e.setBuffer(particles,offset:0,index:0)
        var u=uniforms;e.setBytes(&u,length:MemoryLayout<LabUniforms>.stride,index:1)
        vessels.withUnsafeBytes { e.setBytes($0.baseAddress!,length:$0.count,index:2) }
        e.setBuffer(profilesBuffer,offset:0,index:3)
        layerBands.withUnsafeBytes { e.setBytes($0.baseAddress!,length:$0.count,index:4) }
        e.dispatchThreads(MTLSize(width:particleCount,height:1,depth:1),threadsPerThreadgroup:MTLSize(width:128,height:1,depth:1))
        e.endEncoding()
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
        frontDye = texture(.r16Float,width:width,height:height,usage:[.renderTarget,.shaderRead])
        dyeA = texture(.r16Float,width:width,height:height,usage:[.shaderRead,.shaderWrite])
        dyeB = texture(.r16Float,width:width,height:height,usage:[.shaderRead,.shaderWrite])
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
        constrainLayers(command:command,uniforms:uniforms,vessels:vessels)
        for _ in 0..<5 {
            dispatch("labClearHeads",count:64*48*32,command:command,buffers:[(0,heads)])
            dispatch("labBuildGrid",count:n,command:command,buffers:[(0,particles),(2,heads),(3,next)],uniforms:uniforms)
            dispatch("labLambda",count:n,command:command,buffers:[(0,particles),(2,heads),(3,next),(4,lambdas)],uniforms:uniforms)
            dispatch("labDelta",count:n,command:command,buffers:[(0,particles),(2,heads),(3,next),(4,lambdas),(5,deltas)],uniforms:uniforms)
            dispatch("labApply",count:n,command:command,buffers:[(0,particles),(3,profilesBuffer),(4,deltas)],uniforms:uniforms,vessels:vessels)
            constrainLayers(command:command,uniforms:uniforms,vessels:vessels)
        }
        // Rebuild after the final corrections, before velocity smoothing.
        dispatch("labClearHeads",count:64*48*32,command:command,buffers:[(0,heads)])
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
        if game.pending != nil && !paused { updateTransfer() }
        resize(width:target.width,height:target.height)
        let command = queue.makeCommandBuffer()!
        command.label = "Fluid Lab frame"
        let (vp,view,eye) = LabBoardLayout.camera(aspect:Float(target.width)/Float(target.height), azimuth:orbit)
        var u = LabUniforms(viewProjection:vp,inverseViewProjection:vp.inverse,view:view,camera:SIMD4(eye,Float(game.state.colors.count)),
            viewport:SIMD4(Float(target.width),Float(target.height),pointMode ? spacing*0.30 : spacing*1.02,simulationTime),
            physics:SIMD4(timeStep,spacing*2.3,particleVolume,viscosity),options:SIMD4(UInt32(particleCount),pointMode ? 1:0,4,1 | (funnelEnabled ? 32:0) | (game.pending.map { (1 << ($0.source+1)) | (1 << ($0.destination+1)) } ?? 0)))
        if !paused && !resting {
            accumulator = min(accumulator+min(max(deltaTime,0),1.0/20)*playbackSpeed,timeStep*12)
            var steps = 0
            while accumulator >= timeStep && steps < 12 {
                simulationTime += timeStep
                if pourTime != nil { pourTime! += timeStep }; advancePose()
                var vessels = currentVessels
                for i in vessels.indices {
                    if previousWorlds.count == vessels.count { vessels[i].previousWorld=previousWorlds[i] }
                }
                previousWorlds=vessels.map(\.world)
                layerBands=makeBands()
                var stepUniforms=u
                stepUniforms.viewport.w=simulationTime
                if (pourTime ?? 0) < 0 { stepUniforms.physics.w=max(viscosity,0.35) }
                simulate(command:command,uniforms:stepUniforms,vessels:vessels)
                accumulator -= timeStep; steps += 1
            }
        }
        u.viewport.w = simulationTime
        let vessels = currentVessels
        let surfacePass=pass(color:depth,clear:MTLClearColorMake(1,1,1,1),depth:depthTest)
        surfacePass.colorAttachments[1].texture=frontDye
        surfacePass.colorAttachments[1].loadAction = .clear
        surfacePass.colorAttachments[1].storeAction = .store
        surfacePass.colorAttachments[1].clearColor=MTLClearColorMake(-1,0,0,0)
        let depthEncoder = command.makeRenderCommandEncoder(descriptor:surfacePass)!
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
                e.setComputePipelineState(kernels["labBoardSmoothDepth"]!)
                e.setTexture(input,index:0); e.setTexture(output,index:1)
                var direction=direction
                e.setBytes(&direction,length:MemoryLayout<SIMD2<UInt32>>.stride,index:0)
                e.dispatchThreads(MTLSize(width:target.width,height:target.height,depth:1),threadsPerThreadgroup:MTLSize(width:16,height:16,depth:1))
                e.endEncoding()
            }
        }
        for (input,output,direction) in [(frontDye!,dyeA!,SIMD2<UInt32>(1,0)),(dyeA!,dyeB!,SIMD2<UInt32>(0,1))] {
            let e=command.makeComputeCommandEncoder()!
            e.setComputePipelineState(kernels["labSmoothDye"]!)
            e.setTexture(input,index:0);e.setTexture(output,index:1);e.setTexture(depth,index:2)
            var direction=direction;e.setBytes(&direction,length:MemoryLayout<SIMD2<UInt32>>.stride,index:0)
            e.dispatchThreads(MTLSize(width:target.width,height:target.height,depth:1),threadsPerThreadgroup:MTLSize(width:16,height:16,depth:1))
            e.endEncoding()
        }
        let compose=command.makeRenderCommandEncoder(descriptor:pass(color:scene))!
        compose.label = "Reconstruct and shade liquid"
        compose.setRenderPipelineState(composePipeline)
        compose.setFragmentBytes(&u,length:MemoryLayout<LabUniforms>.stride,index:0)
        compose.setFragmentTexture(pointMode ? depth : smoothB,index:0)
        compose.setFragmentTexture(thickness,index:1)
        compose.setFragmentTexture(dyeB,index:2)
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
        for i in profiles.indices {
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
                if lastCommand?.status == .completed { onUpdate?(lastMetrics,phase,pourTime ?? 0) }
            } else { pausedSignature=nil }
            guard let drawable=view.currentDrawable else { inFlight.signal(); return }
            if frame % 30 == 0, lastCommand?.status == .completed {
                onUpdate?(lastMetrics,phase,pourTime ?? 0)
            }
            let now=CACurrentMediaTime()
            let delta=Float(lastWallTime.map { now-$0 } ?? 1.0/60)
            lastWallTime=now
            let semaphore=inFlight
            let encodeStart=CACurrentMediaTime()
            encodeFrame(target:drawable.texture,deltaTime:delta,present:drawable) { _ in
                semaphore.signal()
            }
            if !resting && !paused { onFrame?(Double(delta),(CACurrentMediaTime()-encodeStart)*1000,lastMetrics.gpuMilliseconds) }
        }
    }
}
