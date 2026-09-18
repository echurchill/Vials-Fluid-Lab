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

private struct LabMetalTransfer {
    let item:LabPourReservation
    let before:[LabParticle]
    var time:Float = -LabBoardTiming.preparation
    var tilt:Float=0
    var cutoff:Float?
    var cutoffTilt:Float=0
    var returned:Float?
    var settleReady=false
    var correction=0
    var arrived=0,departed=0
    var visualSettled=false
}

@MainActor
final class LabBoardRenderer: NSObject, MTKViewDelegate {
    let device:MTLDevice
    private(set) var profiles=LabBoardLayout.profiles()
    private(set) var profileCapacities=[4,4,4,4]
    var homes:[SIMD3<Float>] { LabBoardLayout.homes(count:profiles.count) }
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
    private var settleFrom:[LabParticle]?
    private var settleTargets:[LabParticle]?
    private var groupSettleStart:Float?
    private var previousWorlds:[simd_float4x4]=[]
    private var beforeParticles:[LabParticle]=[]
    private var historyParticles:[[LabParticle]]=[]
    private(set) var lastMetrics=LabBoardMetrics()
    private(set) var correctionCount=0
    private(set) var arrivalBeforeCorrection:Float=0
    private(set) var lastOutcome=""
    private var layerBands:[LabBoardBand]=[]
    private var groupTransfers:[LabMetalTransfer]=[]
    private(set) var groupResults:[LabLaneResult]=[]
    private(set) var groupOwnedParcels:Set<Int>=[]
    var groupMoves:[LabBoardMove] { groupTransfers.map { $0.item.move } }
    var groupFinalSettling:Bool { groupSettleStart != nil }
    var groupStreamActive:Bool { groupTransfers.contains {$0.departed>20 && $0.cutoff==nil} }
    var quality:LabRenderQuality = .automatic
    var funnelEnabled=true
    var paused=false
    var pointMode=false
    var reduceTransparency=false
    var capExclusions:Set<Int>=[] {
        didSet {if oldValue != capExclusions {pausedSignature=nil}}
    }
    var orbit:Float=0.12
    var playbackSpeed:Float=1
    var viscosity:Float=0.10
    var onFrame:((Double,Double,Double)->Void)?
    var onError:((String)->Void)?
    var onUpdate:((LabBoardMetrics,String,Float)->Void)?
    var resting:Bool { game.pending == nil }
    private var compositeVessels:[LabVesselUniform]?
    var currentVessels:[LabVesselUniform] {
        if let compositeVessels { return compositeVessels }
        return LabBoardLayout.vessels(profiles:profiles,capacities:game.state.capacities,move:game.pending,time:pourTime ?? 0,tilt:tilt,
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
    private var capMeshes:[(MTLBuffer,Int)]=[]
    private var kernels: [String: MTLComputePipelineState] = [:]
    private var depthPipeline: MTLRenderPipelineState!
    private var thicknessPipeline: MTLRenderPipelineState!
    private var composePipeline: MTLRenderPipelineState!
    private var glassPipeline: MTLRenderPipelineState!
    private var capPipeline:MTLRenderPipelineState!
    private var copyPipeline: MTLRenderPipelineState!
    private var glassCopyPipeline: MTLRenderPipelineState!
    private(set) var glassSampleCount = 1
    private var glassMultisampleColor: MTLTexture?
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
    private var glassA:MTLTexture!
    private var glassB:MTLTexture!
    private var viewportSize = SIMD2<Int>(0,0)
    private var lastCommand: MTLCommandBuffer?
    var lastGPUWorkMilliseconds:Double {
        guard let lastCommand,lastCommand.status == .completed else { return 0 }
        return max(0,(lastCommand.gpuEndTime-lastCommand.gpuStartTime)*1000)
    }
    private var lastWallTime: CFTimeInterval?
    private var frame = 0
    private var pausedSignature: SIMD4<Float>?
    private weak var renderedView:MTKView?
    private var accumulator: Float = 0
    private var particleVolume: Float = 0
    // Canonical positions depend only on the vessel profile and unit slot.
    // Reuse them when a receiver group starts instead of inverting volume for
    // every particle again on the main actor.
    private var seedPositions:[[SIMD3<Float>]]=[]
    private let inFlight = DispatchSemaphore(value: 3)
    private let spacing: Float = 0.079
    private let timeStep: Float = 1.0 / 120
    var renderedParticleRadius:Float { spacing*(pointMode ? 0.30:1.16) }

    /// Particle billboards reconstruct a surface around their centers. Pack
    /// centers one rendered radius below the common fill line so the visible
    /// 3D surface retains the same physical headspace as Classic and 2D.
    private func particleFillVolume(_ profile:LabVesselProfile)->Float {
        profile.volume(at:max(0.08,profile.height*LabVesselProfile.usableHeightFraction-spacing*1.16))
    }

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
        // Antialias the glass geometry only; fluid reconstruction keeps its
        // existing resolution and particle workload.
        glassSampleCount = device.supportsTextureSampleCount(4) ? 4 : (device.supportsTextureSampleCount(2) ? 2 : 1)
        glassPipeline = try pipeline(vertex: "labGlassVertex", fragment: "labBoardGlassFragment", format: .bgra8Unorm_srgb, depth: true, samples: glassSampleCount)
        capPipeline = try pipeline(vertex: "labGlassVertex", fragment: "labBoardCapFragment", format: .bgra8Unorm_srgb, depth: true, samples: glassSampleCount)
        glassCopyPipeline = try pipeline(vertex: "labFullscreen", fragment: "labCopy", format: .bgra8Unorm_srgb, depth: true, samples: glassSampleCount)
        copyPipeline = try pipeline(vertex: "labFullscreen", fragment: "labCopy", format: .bgra8Unorm_srgb)
        let state = MTLDepthStencilDescriptor()
        state.depthCompareFunction = .lessEqual; state.isDepthWriteEnabled = true
        depthState = device.makeDepthStencilState(descriptor: state)
        profilesBuffer = makeBuffer(profiles.flatMap(\.radii))
        heads = device.makeBuffer(length: 128*48*40*MemoryLayout<Int32>.stride, options: .storageModePrivate)
        meshes = profiles.map { profile in
            let vertices = labGlassMesh(profile,rings:48,segments:64)
            return (makeBuffer(vertices), vertices.count)
        }
        capMeshes=profiles.map { let vertices=labCapMesh($0);return (makeBuffer(vertices),vertices.count) }
        reset()
    }

    private func pipeline(vertex: String, fragment: String, format: MTLPixelFormat,
                          depth: Bool = false, additive: Bool = false, samples: Int = 1) throws -> MTLRenderPipelineState {
        let d = MTLRenderPipelineDescriptor()
        d.label = fragment
        d.rasterSampleCount = samples
        d.vertexFunction = library.makeFunction(name: vertex)
        d.fragmentFunction = library.makeFunction(name: fragment)
        d.colorAttachments[0].pixelFormat = format
        if fragment == "labBoardParticleDepth" { d.colorAttachments[1].pixelFormat = .rgba16Float }
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
        compositeVessels=nil;groupTransfers=[];groupResults=[];groupOwnedParcels=[]
        pourTime=nil;tilt=0;cutoffTime=nil;returnStart=nil;cleanupStart=nil
        settleFrom=nil;settleTargets=nil;groupSettleStart=nil
        previousWorlds=[];accumulator=0;lastWallTime=nil;pausedSignature=nil
        correctionCount=0;arrivalBeforeCorrection=0;lastMetrics=LabBoardMetrics();paused=false
    }
    func reset(state:LabBoardState = .firstSort) {
        lastCommand?.waitUntilCompleted()
        game=LabBoardGame(state:state);simulationTime=0;clearMotion();historyParticles=[];beforeParticles=[];lastOutcome=""
        if profileCapacities != state.capacities {
            profileCapacities=state.capacities;profiles=LabBoardLayout.profiles(capacities:state.capacities);seedPositions=[]
            profilesBuffer=makeBuffer(profiles.flatMap(\.radii))
            meshes=profiles.map { let vertices=labGlassMesh($0,rings:48,segments:64);return (makeBuffer(vertices),vertices.count) }
            capMeshes=profiles.map { let vertices=labCapMesh($0);return (makeBuffer(vertices),vertices.count) }
        }
        let values=seed(state:state)
        particleCount=values.count
        particleVolume=profiles.first.map(particleFillVolume) ?? 1
        particleVolume/=Float(max(1,state.capacities.first ?? 4))*Float(Self.particlesPerUnit)
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
        if seedPositions.count != profiles.count {
            seedPositions=profiles.enumerated().map { owner,profile in
                let capacity=game.state.capacities[owner],unit=particleFillVolume(profile)/Float(capacity)
                return (0..<(capacity*Self.particlesPerUnit)).map { slot in
                    let layer=slot/Self.particlesPerUnit,i=slot%Self.particlesPerUnit
                    let v=(Float(layer)+(Float(i)+0.5)/Float(Self.particlesPerUnit))*unit
                    let y=max(0.04,profile.height(for:v))
                    let r=max(0.01,profile.radius(at:y)-0.042)*sqrt(radical(i+1,2)),a=radical(i+1,3)*2*Float.pi
                    return SIMD3(r*cos(a),y,r*sin(a))
                }
            }
        }
        var values:[LabParticle]=[]
        values.reserveCapacity(state.colors.count*Self.particlesPerUnit)
        let origins=homes
        for (owner,stack) in state.stacks.enumerated() {
            for (layer,parcel) in stack.enumerated() {
                for i in 0..<Self.particlesPerUnit {
                    let p=SIMD4(seedPositions[owner][layer*Self.particlesPerUnit+i]+origins[owner],Float(owner))
                    values.append(LabParticle(position:p,predicted:p,velocity:SIMD4(0,0,0,Float(state.colors[parcel])),visual:SIMD4(0,Float(parcel),0,0)))
                }
            }
        }
        return values
    }
    @discardableResult func begin(from:Int,to:Int,reserved:Bool=false) -> Bool {
        guard game.pending == nil,game.state.move(from:from,to:to) != nil else { return false }
        lastCommand?.waitUntilCompleted()
        beforeParticles=particleSamples()
        clearMotion();lastOutcome=""
        guard let move=game.begin(from:from,to:to,reserved:reserved) else { return false }
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
            tilt=min(2.15,tilt+rate*labSmooth((t-LabBoardTiming.tiltStart)/0.25)*timeStep)
            if t>LabBoardTiming.timeout { cutoffTime=t;cutoffTilt=tilt }
        }
    }
    private func updateTransfer() {
        guard let move=game.pending,let t=pourTime else { return }
        lastMetrics=measure()
        let target=move.amount*Self.particlesPerUnit
        if cutoffTime == nil,lastMetrics.departed>=Int(Float(target)*0.99),lastMetrics.arrived>=target-Int(Float(target)*0.05) {
            cutoffTime=t;cutoffTilt=tilt
        }
        if let cleanup=cleanupStart {
            let progress=(t-cleanup)/0.55
            applySettle(progress:progress)
            if progress>=1 {
                let samples=particleSamples()
                if let after=game.state.applying(move),inventoryMatches(samples,state:after) {
                    historyParticles.append(beforeParticles)
                    _=game.commit(move);lastOutcome="Move complete"
                } else { rollback(message:"That pour needs another try") }
                settleFrom=nil;settleTargets=nil
                pourTime=nil;tilt=0;previousWorlds=[];pausedSignature=nil
            }
        } else if let back=returnStart,t-back>LabBoardTiming.returned+LabBoardTiming.settling {
            let missing=target-lastMetrics.arrived
            arrivalBeforeCorrection=Float(lastMetrics.arrived)/Float(target)
            if missing>=0,missing<=Int(Float(target)*0.05),lastMetrics.wrongParcel==0,lastMetrics.nonFinite==0 {
                correct(move:move)
                if let after=game.state.applying(move) {
                    normalizeOrder(state:after)
                    prepareSettle(owners:[move.source,move.destination],state:after)
                    cleanupStart=t
                } else {rollback(message:"That pour needs another try")}
            } else { rollback(message:"Too much spilled · Try again") }
        }
        // Publish the transaction before idle rendering stops. Waiting for a
        // later GPU-completed draw can leave the controls stuck on "settling".
        if game.pending == nil { onUpdate?(lastMetrics,phase,pourTime ?? 0) }
    }
    private func rollback(message:String) {
        particles=makeBuffer(beforeParticles);game.cancel();pourTime=nil;tilt=0;previousWorlds=[];pausedSignature=nil
        settleFrom=nil;settleTargets=nil;lastOutcome=message
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
        // Claim the stragglers for the destination without teleporting their
        // visible XYZ position. The final-settle interpolation below carries
        // them into the exact fluid body over several frames.
        for i in missing {
            p[i].position.w=Float(move.destination);p[i].predicted=p[i].position
            p[i].velocity=SIMD4(0,0,0,p[i].velocity.w);p[i].visual.x=simulationTime
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
    /// Build an exact target for only the participating vessels. The current
    /// and target buffers are blended during Final settling, so detached
    /// particles rejoin the bulk fluid without a one-frame volume jump.
    private func prepareSettle(owners:Set<Int>,state:LabBoardState) {
        guard !owners.isEmpty else {return}
        let parcels=Set(owners.flatMap {state.stacks[$0]})
        let canonical=Dictionary(grouping:seed(state:state)) {Int($0.visual.y)}
        let current=particleSamples();var targets=current,offsets:[Int:Int]=[:]
        for i in current.indices {
            let parcel=Int(current[i].visual.y)
            guard parcels.contains(parcel),let canonicalParcel=canonical[parcel] else {continue}
            let offset=offsets[parcel,default:0]
            targets[i]=canonicalParcel[offset];offsets[parcel]=offset+1
        }
        settleFrom=current;settleTargets=targets
    }
    private func applySettle(progress:Float) {
        guard let from=settleFrom,let targets=settleTargets else {return}
        let f=labSmooth(min(1,max(0,progress)))
        let p=particles.contents().bindMemory(to:LabParticle.self,capacity:particleCount)
        if progress>=1 {
            for i in 0..<particleCount {p[i]=targets[i]}
            return
        }
        for i in 0..<particleCount where from[i].position != targets[i].position {
            let position=simd_mix(from[i].position,targets[i].position,SIMD4(repeating:f))
            p[i]=targets[i];p[i].position=position;p[i].predicted=position
        }
    }
    private func makeBands() -> [LabBoardBand] {
        let count=game.state.colors.count
        var result=[LabBoardBand](repeating:LabBoardBand(range:SIMD4(-100,100,0,0)),count:count*profiles.count)
        let move=game.pending, selected=Set(move?.parcels ?? [])
        let after=cleanupStart == nil ? nil:move.flatMap { game.state.applying($0) }
        let state=after ?? game.state
        for (owner,stack) in state.stacks.enumerated() {
            let profile=profiles[owner]
            var levels:[Float]=[-100]
            let fillVolume=particleFillVolume(profile)
            for layer in 1...max(1,stack.count) { levels.append(profile.height(for:fillVolume*Float(layer)/Float(state.capacities[owner]))) }
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
            let lower=game.state.stacks[move.destination].isEmpty ? -100:profile.height(for:particleFillVolume(profile)*Float(game.state.stacks[move.destination].count)/Float(game.state.capacities[move.destination]))
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
    private func texture(_ format: MTLPixelFormat, width: Int, height: Int, usage: MTLTextureUsage, samples: Int = 1) -> MTLTexture {
        let d = MTLTextureDescriptor.texture2DDescriptor(pixelFormat:format,width:width,height:height,mipmapped:false)
        d.storageMode = .private; d.usage = usage
        if samples > 1 { d.textureType = .type2DMultisample; d.sampleCount = samples }
        return device.makeTexture(descriptor:d)!
    }

    private func resize(width: Int, height: Int) {
        guard viewportSize != SIMD2(width,height) else { return }
        lastCommand?.waitUntilCompleted()
        viewportSize = SIMD2(width,height)
        depth = texture(.r32Float,width:width,height:height,usage:[.renderTarget,.shaderRead])
        frontDye = texture(.rgba16Float,width:width,height:height,usage:[.renderTarget,.shaderRead])
        dyeA = texture(.rgba16Float,width:width,height:height,usage:[.shaderRead,.shaderWrite])
        dyeB = texture(.rgba16Float,width:width,height:height,usage:[.shaderRead,.shaderWrite])
        smoothA = texture(.r32Float,width:width,height:height,usage:[.shaderRead,.shaderWrite])
        smoothB = texture(.r32Float,width:width,height:height,usage:[.shaderRead,.shaderWrite])
        depthTest = texture(.depth32Float,width:width,height:height,usage:.renderTarget)
        thickness = texture(.rgba16Float,width:width,height:height,usage:[.renderTarget,.shaderRead])
        scene = texture(.rgba16Float,width:width,height:height,usage:[.renderTarget,.shaderRead])
        // Retain multisample depth across overlapping glass batches so the
        // front/back ordering is evaluated at the same coverage samples.
        glassDepth = texture(.depth32Float,width:width,height:height,usage:.renderTarget,samples:glassSampleCount)
        glassMultisampleColor = glassSampleCount > 1 ? texture(.bgra8Unorm_srgb,width:width,height:height,usage:.renderTarget,samples:glassSampleCount) : nil
        glassA = texture(.bgra8Unorm_srgb,width:width,height:height,usage:[.shaderRead,.renderTarget])
        glassB = texture(.bgra8Unorm_srgb,width:width,height:height,usage:[.shaderRead,.renderTarget])
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
            dispatch("labClearHeads",count:128*48*40,command:command,buffers:[(0,heads)])
            dispatch("labBuildGrid",count:n,command:command,buffers:[(0,particles),(2,heads),(3,next)],uniforms:uniforms)
            dispatch("labLambda",count:n,command:command,buffers:[(0,particles),(2,heads),(3,next),(4,lambdas)],uniforms:uniforms)
            dispatch("labDelta",count:n,command:command,buffers:[(0,particles),(2,heads),(3,next),(4,lambdas),(5,deltas)],uniforms:uniforms)
            dispatch("labApply",count:n,command:command,buffers:[(0,particles),(3,profilesBuffer),(4,deltas)],uniforms:uniforms,vessels:vessels)
            constrainLayers(command:command,uniforms:uniforms,vessels:vessels)
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
    private func encodeSimulation(command:MTLCommandBuffer,uniforms:LabUniforms,deltaTime:Float) {
        // Final settling owns the participating particle positions directly.
        // Running another physics step here would project newly claimed
        // stragglers into the receiver before their visible interpolation.
        if !paused && !resting && cleanupStart != nil {
            accumulator=min(accumulator+min(max(deltaTime,0),1.0/20)*playbackSpeed,timeStep*12)
            while accumulator>=timeStep {
                simulationTime+=timeStep;pourTime!+=timeStep;accumulator-=timeStep
            }
        } else if !paused && !resting {
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
                var stepUniforms=uniforms
                stepUniforms.viewport.w=simulationTime
                if (pourTime ?? 0) < 0 || returnStart != nil { stepUniforms.physics.w=max(viscosity,0.30) }
                simulate(command:command,uniforms:stepUniforms,vessels:vessels)
                accumulator -= timeStep; steps += 1
            }
        }
    }
    /// Simulation lanes own their solver buffers and omit surface rendering.
    convenience init(simulationCopyOf source:LabBoardRenderer) throws {
        try self.init(device:source.device,library:source.library)
        // Warm both receiver slots before play. Profile data and canonical
        // positions are immutable; each lane still owns its particle buffers.
        profiles=source.profiles;profilesBuffer=source.profilesBuffer;meshes=source.meshes
        seedPositions=source.seedPositions
        reset(state:source.game.state)
    }
    func installSimulation(game:LabBoardGame,samples:[LabParticle],vessels:Set<Int>) {
        install(game:game)
        let ids=Set(vessels.flatMap { game.state.stacks[$0] })
        let local=particleSamples().filter { !ids.contains(Int($0.visual.y)) }+samples.filter { ids.contains(Int($0.visual.y)) }
        precondition(local.count==particleCount)
        particles=makeBuffer(local)
    }
    func advanceSimulation(deltaTime:Float) {
        if game.pending != nil && !paused { updateTransfer() }
        guard !paused,!resting else { return }
        let command=queue.makeCommandBuffer()!
        let (vp,view,eye)=LabBoardLayout.camera(aspect:1,azimuth:orbit,vesselCount:profiles.count)
        let u=LabUniforms(viewProjection:vp,inverseViewProjection:vp.inverse,view:view,camera:SIMD4(eye,Float(game.state.colors.count)),
            viewport:SIMD4(1,1,spacing*1.16,simulationTime),physics:SIMD4(timeStep,spacing*2.3,particleVolume,viscosity),
            options:SIMD4(UInt32(particleCount),0,UInt32(profiles.count),1 | (funnelEnabled ? 65536:0) | (game.pending.map { (1 << ($0.source+1)) | (1 << ($0.destination+1)) } ?? 0)))
        encodeSimulation(command:command,uniforms:u,deltaTime:deltaTime)
        lastCommand=command;command.commit()
    }
    /// One receiver and all its incoming streams share a single particle buffer.
    func advanceGroup(game:LabBoardGame,starts:[LabPourReservation],samples:[LabParticle],deltaTime:Float) {
        lastCommand?.waitUntilCompleted();groupResults=[]
        if !starts.isEmpty {
            // A late shared-receiver pour changes the owned parcel set. Rebuild
            // once and discard any prior interpolation target; unrelated groups
            // finishing must not reorder this buffer underneath an active settle.
            groupSettleStart=nil;settleFrom=nil;settleTargets=nil
            for i in groupTransfers.indices {groupTransfers[i].visualSettled=false}
            let moves=groupMoves+starts.map(\.move),owners=Set(moves.flatMap {[$0.source,$0.destination]})
            let owned=Set(owners.flatMap {game.state.stacks[$0]}+moves.flatMap(\.parcels))
            let current=particleSamples().filter {owned.contains(Int($0.visual.y))}
            let stable=seed(state:game.state).filter {!owned.contains(Int($0.visual.y))}
            particles=makeBuffer(current+stable)
        }
        self.game=game
        for item in starts {
            guard game.state.applyingReserved(item.move) != nil else { groupResults.append(LabLaneResult(id:item.id,committed:false,cleanup:0));continue }
            let sourceIDs=Set(game.state.stacks[item.move.source])
            let local=particleSamples().filter {!sourceIDs.contains(Int($0.visual.y))}+samples.filter {sourceIDs.contains(Int($0.visual.y))}
            particles=makeBuffer(local)
            groupOwnedParcels.formUnion(sourceIDs);groupOwnedParcels.formUnion(game.state.stacks[item.move.destination])
            groupTransfers.append(LabMetalTransfer(item:item,before:local.filter {sourceIDs.contains(Int($0.visual.y))}))
        }
        updateGroupTransfers()
        let owners=Set(groupMoves.flatMap {[$0.source,$0.destination]}+groupResults.flatMap(\.vessels))
        groupOwnedParcels=Set(owners.flatMap {self.game.state.stacks[$0]}+groupMoves.flatMap(\.parcels))
        guard !groupTransfers.isEmpty else { return }
        if groupSettleStart != nil {
            accumulator=min(accumulator+min(max(deltaTime,0),1.0/20)*playbackSpeed,timeStep*12)
            while accumulator>=timeStep {
                simulationTime+=timeStep
                accumulator-=timeStep
            }
            return
        }
        // Once the receiver has reached its canonical, headspaced level, keep
        // those particles fixed while the now-empty sources return home. This
        // makes the cap a completion cue instead of a late visual top-off.
        if groupTransfers.allSatisfy(\.visualSettled) {
            accumulator=min(accumulator+min(max(deltaTime,0),1.0/20)*playbackSpeed,timeStep*12)
            while accumulator>=timeStep {
                simulationTime+=timeStep;advanceGroupMotion()
                accumulator-=timeStep
            }
            compositeVessels=groupVessels()
            return
        }
        let selected=Set(groupMoves.flatMap(\.parcels))
        let pointer=particles.contents().bindMemory(to:LabParticle.self,capacity:particleCount)
        for i in 0..<particleCount { pointer[i].visual.z=selected.contains(Int(pointer[i].visual.y)) ? 1:0 }
        let command=queue.makeCommandBuffer()!;command.label="Shared receiver physics"
        accumulator=min(accumulator+min(max(deltaTime,0),1.0/20)*playbackSpeed,timeStep*12)
        let active=Set(groupMoves.flatMap {[$0.source,$0.destination]})
        let flags=active.reduce(UInt32(1 | (funnelEnabled ? 65536:0))) { $0 | (1 << ($1+1)) }
        let (vp,view,eye)=LabBoardLayout.camera(aspect:1,azimuth:orbit,vesselCount:profiles.count)
        var u=LabUniforms(viewProjection:vp,inverseViewProjection:vp.inverse,view:view,camera:SIMD4(eye,Float(game.state.colors.count)),
            viewport:SIMD4(1,1,spacing*1.16,simulationTime),physics:SIMD4(timeStep,spacing*2.3,particleVolume,viscosity),options:SIMD4(UInt32(particleCount),0,UInt32(profiles.count),flags))
        var steps=0
        while accumulator>=timeStep,steps<12 {
            simulationTime+=timeStep
            advanceGroupMotion()
            var vessels=groupVessels()
            for i in vessels.indices { vessels[i].previousWorld=previousWorlds.count==vessels.count ? previousWorlds[i]:vessels[i].world }
            previousWorlds=vessels.map(\.world);compositeVessels=vessels
            layerBands=groupBands();u.viewport.w=simulationTime
            simulate(command:command,uniforms:u,vessels:vessels)
            accumulator-=timeStep;steps+=1
        }
        lastCommand=command;command.commit()
    }
    private func advanceGroupMotion() {
        for i in groupTransfers.indices {
            groupTransfers[i].time+=timeStep
            let t=groupTransfers[i].time
            if let stop=groupTransfers[i].cutoff {
                let elapsed=t-stop,initial=groupTransfers[i].cutoffTilt
                if elapsed<LabBoardTiming.stop { groupTransfers[i].tilt=initial-min(0.45,initial)*labSmooth(elapsed/LabBoardTiming.stop) }
                else { groupTransfers[i].tilt=max(0,initial-0.45)*(1-labSmooth((elapsed-LabBoardTiming.stop)/LabBoardTiming.upright)) }
                if elapsed>=LabBoardTiming.untilted,groupTransfers[i].returned==nil { groupTransfers[i].returned=t }
            } else if t>=LabBoardTiming.tiltStart {
                let rate=groupTransfers[i].departed<20 ? LabBoardTiming.approachRate:LabBoardTiming.pouringRate
                groupTransfers[i].tilt=min(2.15,groupTransfers[i].tilt+rate*labSmooth((t-LabBoardTiming.tiltStart)/0.25)*timeStep)
                if t>LabBoardTiming.timeout { groupTransfers[i].cutoff=t;groupTransfers[i].cutoffTilt=groupTransfers[i].tilt }
            }
        }
    }
    private func groupVessels()->[LabVesselUniform] {
        var result=LabBoardLayout.vessels(profiles:profiles,capacities:game.state.capacities,move:nil,time:0,tilt:0,cutoffTilt:nil,cutoffElapsed:0,returnElapsed:nil)
        for job in groupTransfers {
            let move=job.item.move
            let poses=LabBoardLayout.vessels(profiles:profiles,capacities:game.state.capacities,move:move,time:job.time,tilt:job.tilt,cutoffTilt:job.cutoff==nil ? nil:job.cutoffTilt,cutoffElapsed:job.time-(job.cutoff ?? 0),returnElapsed:job.returned.map {job.time-$0},approach:job.item.approach,depthSide:job.item.depthSide)
            result[move.source]=poses[move.source];result[move.destination]=poses[move.destination]
        }
        return result
    }
    private func groupBands()->[LabBoardBand] {
        let state=game.state,count=state.colors.count
        var bands=[LabBoardBand](repeating:LabBoardBand(range:SIMD4(-100,100,0,0)),count:count*profiles.count)
        for (owner,original) in state.stacks.enumerated() {
            let outgoing=groupMoves.first {$0.source==owner}
            let selected=Set(outgoing?.parcels ?? [])
            let stack=original+groupMoves.filter {$0.destination==owner}.flatMap(\.parcels)
            let profile=profiles[owner]
            let fillVolume=particleFillVolume(profile)
            func level(_ unit:Int)->Float { unit==0 ? -100:profile.height(for:fillVolume*Float(unit)/Float(game.state.capacities[owner])) }
            for (layer,id) in stack.enumerated() {
                var first=layer,last=layer+1
                while first>0,state.colors[stack[first-1]]==state.colors[id],!selected.contains(stack[first-1]) {first-=1}
                while last<stack.count,state.colors[stack[last]]==state.colors[id],!selected.contains(stack[last]) {last+=1}
                let moving=selected.contains(id)
                let lower=moving ? level(original.count-(outgoing?.amount ?? 0)):level(first)
                let upper:Float=moving || last==stack.count ? 100:level(last)
                bands[owner*count+id]=LabBoardBand(range:SIMD4(lower,upper,1,1))
            }
        }
        return bands
    }
    private func updateGroupTransfers() {
        if let start=groupSettleStart {
            let progress=(simulationTime-start)/0.55
            applySettle(progress:progress)
            if progress>=1 {
                for i in groupTransfers.indices {groupTransfers[i].visualSettled=true}
                groupSettleStart=nil;settleFrom=nil;settleTargets=nil
            }
            compositeVessels=groupVessels()
            return
        }
        if !groupTransfers.isEmpty,groupTransfers.allSatisfy(\.visualSettled) {
            guard groupTransfers.allSatisfy({job in job.returned.map {job.time-$0>=LabBoardTiming.returned} ?? false}) else {
                compositeVessels=groupVessels();return
            }
            let jobs=groupTransfers
            for job in jobs {
                let move=job.item.move,target=move.amount*Self.particlesPerUnit
                let committed=self.game.commitReserved(move)
                groupResults.append(LabLaneResult(id:job.item.id,committed:committed,
                    cleanup:100*Float(job.correction)/Float(target),vessels:[move.source,move.destination],
                    diagnostic:"arrived=\(job.arrived)/\(target) departed=\(job.departed) time=\(job.time)"))
            }
            groupTransfers=[];normalizeOrder(state:self.game.state);compositeVessels=groupVessels()
            return
        }
        let values=particleSamples();var finished:[Int]=[];lastMetrics=LabBoardMetrics()
        let moves=groupMoves,owners=Set(moves.flatMap {[$0.source,$0.destination]})
        let selected=Set(moves.flatMap(\.parcels))
        let originalOwners=Dictionary(uniqueKeysWithValues:game.state.stacks.enumerated().flatMap { owner,stack in stack.map {($0,owner)} })
        for particle in values {
            guard [particle.position.x,particle.position.y,particle.position.z,particle.position.w,particle.visual.y].allSatisfy(\.isFinite) else {lastMetrics.nonFinite+=1;continue}
            let id=Int(particle.visual.y),owner=Int(particle.position.w)
            guard selected.contains(id) || originalOwners[id].map({owners.contains($0)}) == true else {continue}
            if owner<0 {lastMetrics.outside+=1}
            if !selected.contains(id),originalOwners[id] != owner {lastMetrics.wrongParcel+=1}
        }
        for j in groupTransfers.indices {
            var job=groupTransfers[j];let move=job.item.move,ids=Set(move.parcels),target=move.amount*Self.particlesPerUnit
            let moving=values.filter {ids.contains(Int($0.visual.y))}
            job.arrived=moving.filter {Int($0.position.w)==move.destination}.count
            job.departed=moving.filter {Int($0.position.w) != move.source}.count
            lastMetrics.arrived+=job.arrived;lastMetrics.departed+=job.departed
            lastMetrics.guided+=moving.filter {$0.visual.w>0.5}.count
            if job.cutoff==nil,job.departed>=Int(Float(target)*0.99),job.arrived>=target-Int(Float(target)*0.05) {job.cutoff=job.time;job.cutoffTilt=job.tilt}
            var failed=false
            if !job.settleReady,job.returned != nil {
                let missing=target-job.arrived
                if missing>=0,missing<=Int(Float(target)*0.05),lastMetrics.wrongParcel==0,lastMetrics.nonFinite==0,moving.allSatisfy({$0.position.x.isFinite && $0.position.y.isFinite && $0.position.z.isFinite}) {
                    // Freeze every source over the receiver while its complete
                    // fluid body settles. Only after this interpolation will
                    // the empty source begin its visible return.
                    job.correction=missing;job.settleReady=true
                } else {failed=true}
            }
            if failed {
                let sourceIDs=Set(job.before.map {Int($0.visual.y)})
                particles=makeBuffer(particleSamples().filter {!sourceIDs.contains(Int($0.visual.y))}+job.before)
                groupResults.append(LabLaneResult(id:job.item.id,committed:false,cleanup:0,
                    vessels:[move.source,move.destination],diagnostic:"arrived=\(job.arrived)/\(target) departed=\(job.departed) time=\(job.time)"))
                finished.append(j)
            }
            groupTransfers[j]=job
        }
        for i in finished.reversed() {groupTransfers.remove(at:i)}
        compositeVessels=groupVessels()
        if !groupTransfers.isEmpty,groupTransfers.allSatisfy(\.settleReady) {
            var projected=self.game.state
            for job in groupTransfers {
                guard let next=projected.applyingReserved(job.item.move) else {return}
                projected=next
            }
            let owners=Set(groupTransfers.flatMap {[$0.item.move.source,$0.item.move.destination]})
            prepareSettle(owners:owners,state:projected)
            groupSettleStart=simulationTime
        }
    }
    func displayComposite(game:LabBoardGame,samples:[LabParticle],vessels:[LabVesselUniform]) {
        lastCommand?.waitUntilCompleted()
        precondition(samples.count==particleCount)
        samples.withUnsafeBytes { bytes in particles.contents().copyMemory(from:bytes.baseAddress!,byteCount:bytes.count) }
        self.game=game;compositeVessels=vessels;pausedSignature=nil
    }

    @discardableResult
    func encodeFrame(target: MTLTexture, deltaTime: Float, present: CAMetalDrawable? = nil, completion: MTLCommandBufferHandler? = nil) -> MTLCommandBuffer {
        if game.pending != nil && !paused { updateTransfer() }
        resize(width:target.width,height:target.height)
        let command = queue.makeCommandBuffer()!
        command.label = "Fluid Lab frame"
        let (vp,view,eye) = LabBoardLayout.camera(aspect:Float(target.width)/Float(target.height), azimuth:orbit,vesselCount:profiles.count)
        var u = LabUniforms(viewProjection:vp,inverseViewProjection:vp.inverse,view:view,camera:SIMD4(eye,Float(game.state.colors.count)),
            viewport:SIMD4(Float(target.width),Float(target.height),pointMode ? spacing*0.30 : spacing*1.16,simulationTime),
            physics:SIMD4(timeStep,spacing*2.3,particleVolume,viscosity),options:SIMD4(UInt32(particleCount),pointMode ? 1:0,UInt32(profiles.count),1 | (funnelEnabled ? 65536:0) | (game.pending.map { (1 << ($0.source+1)) | (1 << ($0.destination+1)) } ?? 0)))
        encodeSimulation(command:command,uniforms:u,deltaTime:deltaTime)
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
        // Batch non-overlapping shells. Only overlapping silhouettes require
        // another sampled layer; a normal resting board is usually one batch.
        let movingCaps=Set(groupMoves.flatMap { [$0.source,$0.destination] }+(game.pending.map { [$0.source,$0.destination] } ?? []))
        let excludedCaps=capExclusions.union(movingCaps)
        func capColor(_ index:Int)->SIMD4<Float>? {
            guard !excludedCaps.contains(index),game.state.isComplete(index),let parcel=game.state.stacks[index].first else { return nil }
            let palette:[SIMD4<Float>]=[
                SIMD4(0.05,0.58,0.86,1),SIMD4(0.96,0.34,0.07,1),SIMD4(0.20,0.76,0.36,1),SIMD4(0.94,0.34,0.65,1),
                SIMD4(1.00,0.72,0.08,1),SIMD4(0.98,0.71,0.61,1),SIMD4(0.55,0.30,0.95,1),SIMD4(0.12,0.78,0.62,1),
                SIMD4(0.72,0.04,0.24,1),SIMD4(0.08,0.24,0.88,1),SIMD4(0.54,0.78,0.06,1),SIMD4(0.82,0.78,0.68,1)]
            let color=game.state.colors[parcel]
            return palette[(color % palette.count+palette.count)%palette.count]
        }
        func bounds(_ i:Int)->CGRect {
            let capRadius=capColor(i)==nil ? Float(0):(profiles[i].radii.last!+0.065)
            let radius=max(profiles[i].radii.max() ?? 0.6,capRadius),height=profiles[i].height+(capRadius>0 ? 0.18:0)
            var x:[CGFloat]=[],y:[CGFloat]=[]
            for a:Float in [-radius,radius] {for b:Float in [0,height] {for c:Float in [-radius,radius] {
                let clip=vp*vessels[i].world*SIMD4(a,b,c,1)
                x.append(CGFloat(clip.x/clip.w));y.append(CGFloat(clip.y/clip.w))
            }}}
            return CGRect(x:x.min()!,y:y.min()!,width:x.max()!-x.min()!,height:y.max()!-y.min()!).insetBy(dx:-0.025,dy:-0.025)
        }
        let ordered=profiles.indices.sorted {
            (view*vessels[$0].world*SIMD4<Float>(0,profiles[$0].height/2,0,1)).z < (view*vessels[$1].world*SIMD4<Float>(0,profiles[$1].height/2,0,1)).z
        }
        var batches:[[Int]]=[],current:[Int]=[]
        let rects=profiles.indices.map {bounds($0)}
        for i in ordered {
            if current.contains(where:{rects[$0].intersects(rects[i])}) {batches.append(current);current=[]}
            current.append(i)
        }
        if !current.isEmpty {batches.append(current)}
        var rear:MTLTexture=scene
        for (index,batch) in batches.enumerated() {
            let output:MTLTexture=index%2==0 ? glassA:glassB
            let descriptor=pass(color:glassMultisampleColor ?? output,depth:glassDepth)
            if glassSampleCount > 1 {
                descriptor.colorAttachments[0].resolveTexture=output
                descriptor.colorAttachments[0].storeAction = .multisampleResolve
            }
            descriptor.depthAttachment.loadAction=index==0 ? .clear:.load
            descriptor.depthAttachment.storeAction = .store
            let glass=command.makeRenderCommandEncoder(descriptor:descriptor)!
            glass.label="Depth-ordered glass layer"
            glass.setRenderPipelineState(glassCopyPipeline);glass.setFragmentTexture(rear,index:0)
            glass.drawPrimitives(type:.triangle,vertexStart:0,vertexCount:3)
            glass.setRenderPipelineState(glassPipeline);glass.setDepthStencilState(depthState);glass.setCullMode(.none)
            glass.setVertexBytes(&u,length:MemoryLayout<LabUniforms>.stride,index:1)
            glass.setFragmentBytes(&u,length:MemoryLayout<LabUniforms>.stride,index:1)
            glass.setFragmentTexture(rear,index:0);glass.setFragmentTexture(depth,index:1)
            var clarity:Float=reduceTransparency ? 0:1
            glass.setFragmentBytes(&clarity,length:MemoryLayout<Float>.stride,index:3)
            for i in batch {
                var vessel=vessels[i]
                glass.setVertexBuffer(meshes[i].0,offset:0,index:0)
                glass.setVertexBytes(&vessel,length:MemoryLayout<LabVesselUniform>.stride,index:2)
                glass.setFragmentBytes(&vessel,length:MemoryLayout<LabVesselUniform>.stride,index:2)
                glass.drawPrimitives(type:.triangle,vertexStart:0,vertexCount:meshes[i].1)
            }
            glass.setRenderPipelineState(capPipeline)
            for i in batch {
                guard var color=capColor(i) else { continue }
                var vessel=vessels[i]
                glass.setVertexBuffer(capMeshes[i].0,offset:0,index:0)
                glass.setVertexBytes(&vessel,length:MemoryLayout<LabVesselUniform>.stride,index:2)
                glass.setFragmentBytes(&color,length:MemoryLayout<SIMD4<Float>>.stride,index:3)
                glass.drawPrimitives(type:.triangle,vertexStart:0,vertexCount:capMeshes[i].1)
            }
            glass.endEncoding();rear=output
        }
        let final=command.makeRenderCommandEncoder(descriptor:pass(color:target))!
        final.setRenderPipelineState(copyPipeline);final.setFragmentTexture(rear,index:0)
        final.drawPrimitives(type:.triangle,vertexStart:0,vertexCount:3);final.endEncoding()
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

    nonisolated func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {
        MainActor.assumeIsolated { pausedSignature=nil }
    }
    nonisolated func draw(in view: MTKView) {
        MainActor.assumeIsolated {
            guard inFlight.wait(timeout:.now()) == .success else { return }
            let bounds=view.bounds.size
            // A newly attached surface can draw before SwiftUI finishes layout.
            // Never cache that provisional aspect ratio as a completed idle frame.
            guard bounds.width>0,bounds.height>0 else { inFlight.signal();return }
            let scale=min(1.5,quality.maximumDimension/max(bounds.width,bounds.height))
            let desired=CGSize(width:max(1,Int(bounds.width*scale)),height:max(1,Int(bounds.height*scale)))
            if view.drawableSize != desired { view.drawableSize=desired }
            if lastCommand?.status == .error {
                onError?(lastCommand?.error?.localizedDescription ?? "The GPU could not complete a frame.")
                view.isPaused=true
                inFlight.signal()
                return
            }
            let signature=SIMD4<Float>(Float(desired.width),Float(desired.height),orbit,pointMode ? 1:0)
            if paused || resting {
                if renderedView === view,pausedSignature == signature { inFlight.signal(); return }
                if lastCommand?.status == .completed { onUpdate?(lastMetrics,phase,pourTime ?? 0) }
            } else { pausedSignature=nil }
            guard let drawable=view.currentDrawable else { inFlight.signal(); return }
            // MTKView may return the previous drawable during a resize. Presenting
            // it stretches the old camera projection beneath correctly placed hints.
            guard drawable.texture.width==Int(desired.width),drawable.texture.height==Int(desired.height) else { inFlight.signal();return }
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
            renderedView=view
            pausedSignature=(paused || resting) ? signature:nil
            if !resting && !paused { onFrame?(Double(delta),(CACurrentMediaTime()-encodeStart)*1000,lastMetrics.gpuMilliseconds) }
        }
    }
}
