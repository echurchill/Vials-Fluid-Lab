import Foundation
import simd

/// Planar particles with no depth coordinate or 3D neighbor search.
/// Their displayed bulk follows the shared vessel's projected volume, rather
/// than independently resizing glass to force equal cross-sectional areas.
nonisolated struct Lab2DProfile:Sendable {
    let source:LabVesselProfile
    let scale:Float=1
    let capacity:Int
    var height:Float { source.height }
    init(_ source:LabVesselProfile,capacity:Int) {
        self.source=source;self.capacity=capacity
        // Cache the volume-to-height projection: level() is called per particle.
        levels=(0...128).map {source.height(for:source.usableVolume*Float($0)/128)}
    }
    private let levels:[Float]
    func radius(_ y:Float)->Float { source.radius(at:y) }
    func level(_ units:Float)->Float {
        let f=min(128,max(0,units/Float(capacity)*128)),i=min(127,Int(f))
        return levels[i]+(levels[i+1]-levels[i])*(f-Float(i))
    }
}
nonisolated struct Lab2DPose:Sendable {
    var base:SIMD2<Float>
    var angle:Float=0
    func rotate(_ p:SIMD2<Float>)->SIMD2<Float> { SIMD2(cos(angle)*p.x+sin(angle)*p.y,-sin(angle)*p.x+cos(angle)*p.y) }
    func world(_ p:SIMD2<Float>)->SIMD2<Float> { base+rotate(p) }
    func local(_ p:SIMD2<Float>)->SIMD2<Float> { let d=p-base;return SIMD2(cos(angle)*d.x-sin(angle)*d.y,sin(angle)*d.x+cos(angle)*d.y) }
}
nonisolated struct Lab2DParticle:Equatable,Sendable {
    var position:SIMD2<Float>
    var velocity=SIMD2<Float>.zero
    var owner:Int
    var inBulk=true // False while falling through air or the empty part of a receiver.
    let parcel:Int
    let color:Int
}
nonisolated struct Lab2DMotion:Sendable {
    let lift:Float,travel:Float,tiltRate:Float,upright:Float,returnTravel:Float,lower:Float,settle:Float,cleanup:Float
    static let relaxed=Self(lift:0.50,travel:0.45,tiltRate:0.78,upright:0.70,returnTravel:0.45,lower:0.45,settle:0.55,cleanup:0.35)
    static let quick=Self(lift:0.40,travel:0.35,tiltRate:1.0,upright:0.50,returnTravel:0.33,lower:0.33,settle:0.29,cleanup:0.20)
    var tiltStart:Float { lift+travel }
    var returned:Float { upright+returnTravel+lower }
}
/// Visual response only: these settings never change particle mass or puzzle rules.
nonisolated struct Lab2DMaterial:Sendable {
    let waveHeight:Float,frequency:Float,damping:Float,splashSpeed:Float
    let harmonics:Float
    static func forColor(_ color:Int)->Self {
        switch color {
        case 0: return Self(waveHeight:0.022,frequency:13,damping:3.2,splashSpeed:1.65,harmonics:2)
        case 1: return Self(waveHeight:0.017,frequency:9,damping:2.5,splashSpeed:1.25,harmonics:2)
        default: return Self(waveHeight:0.014,frequency:6,damping:1.8,splashSpeed:0.9,harmonics:1)
        }
    }
}
nonisolated struct Lab2DSurfaceState:Sendable,Equatable {
    var energy:Float=0,phase:Float=0,impactX:Float=0
    var color=0
    // Each basis has zero mean over the vial width; a ripple does not add a layer.
    func offset(x:Float,halfWidth:Float,envelope:Float)->Float {
        let material=Lab2DMaterial.forColor(color),u=min(1,max(-1,x/max(0.01,halfWidth)))
        return material.waveHeight*energy*envelope*(cos(material.harmonics * .pi*(u-impactX/max(0.01,halfWidth)))*sin(phase)+0.3*sin(2 * .pi*(u-impactX/max(0.01,halfWidth)))*cos(phase*0.7))/1.3
    }
}
nonisolated struct Lab2DSplash:Sendable,Equatable {
    let owner:Int,color:Int,origin:SIMD2<Float>,velocity:SIMD2<Float>
    var age:Float=0
    var position:SIMD2<Float> { origin+velocity*age+SIMD2(0,-4.9*age*age) }
}
nonisolated struct Lab2DTransfer:Sendable {
    let item:LabPourReservation
    let sourceParcels:Set<Int>
    let before:[Lab2DParticle]
    var time:Float=0
    var cutoff:Float?
    var angle:Float=0
    var arrived=0,departed=0
    var cleanup:Float=0
    var targets:[Int:Lab2DParticle]=[:]
    var cleanupStart:Float?
}

nonisolated struct LabFluid2D:Sendable {
    private(set) var mixing:LabMixTransition?
    private var mixFrom:[Lab2DParticle]=[]
    private var mixTargets:[Lab2DParticle]=[]
    private var transfers:[Lab2DTransfer]=[]
    private var groupMode=false
    private(set) var groupResults:[LabLaneResult]=[]
    var groupMoves:[LabBoardMove] { transfers.map { $0.item.move } }
    static let particlesPerUnit=96
    static let step:Float=1/120
    var quickMotion=false
    var motion:Lab2DMotion { quickMotion ? .quick:.relaxed }
    private(set) var materialTimes:[Float]=[]
    private(set) var surfaces:[Lab2DSurfaceState]=[]
    private(set) var splashes:[Lab2DSplash]=[]
    private var lastSplashTime:Float = -1
    private var splashSerial=0
    private var displayPoses:[Int:Lab2DPose]=[:]
    private(set) var displayMoves:[LabBoardMove]=[]
    private var displayEnvelope:Float?
    private var displayStreamActive:Bool?
    var streamActive:Bool { displayStreamActive ?? (busy && departed>0 && cutoff==nil) }
    var surfaceEnvelope:Float {
        if let displayEnvelope { return displayEnvelope }
        guard busy else { return 0 }
        guard let cutoff else { return 1 }
        return 1-labSmooth((time-cutoff)/max(0.01,motion.returned+motion.settle))
    }
    let radius:Float=0.037
    let separation:Float=0.084
    private(set) var profiles:[Lab2DProfile]=[]
    private(set) var particles:[Lab2DParticle]=[]
    private(set) var game=LabBoardGame()
    private(set) var time:Float=0
    private(set) var cutoff:Float?
    private(set) var cleanupPercent:Float=0
    private(set) var arrived=0
    private(set) var departed=0
    private(set) var lastOutcome=""
    private(set) var cpuMilliseconds:Double=0
    private var accumulator:Float=0
    var pendingSimulationSeconds:Float { max(0,accumulator) }
    private var before:[Lab2DParticle]=[]
    private var targets:[Lab2DParticle]?
    private var targetStart:Float=0
    private var stopAngle:Float=0
    private var heads=[Int](repeating:-1,count:160*96)
    private var links:[Int]=[]
    private var selected:Set<Int>=[]
    private var bulkUnits:[Float]=[]
    private var densityJoinedUnits:Float=0
    private var densityBands:[Int:SIMD2<Float>]=[:]
    var busy:Bool { game.pending != nil || !displayMoves.isEmpty || !transfers.isEmpty }
    var phase:String {
        if targets != nil { return "Final settling" }
        if cutoff != nil { return "Returning the vial" }
        if time<motion.lift { return "Lifting the vial" }
        if time<motion.tiltStart { return "Moving into position" }
        return "Pouring"
    }
    init(game:LabBoardGame=LabBoardGame()) { install(game) }
    func home(_ i:Int)->SIMD2<Float> { SIMD2((Float(i)-Float(profiles.count-1)/2)*2.2,0) }
    func pose(_ i:Int)->Lab2DPose {
        if let displayed=displayPoses[i] { return displayed }
        let home=home(i)
        if groupMode {
            guard let transfer=transfers.first(where:{$0.item.move.source==i}) else { return Lab2DPose(base:home) }
            return pourPose(i,move:transfer.item.move,time:transfer.time,cutoff:transfer.cutoff,stopAngle:transfer.angle,approach:transfer.item.approach)
        }
        guard let move=game.pending,i==move.source else { return Lab2DPose(base:home) }
        return pourPose(i,move:move,time:time,cutoff:cutoff,stopAngle:stopAngle,approach:0)
    }
    private func pourPose(_ i:Int,move:LabBoardMove,time:Float,cutoff:Float?,stopAngle:Float,approach:Float)->Lab2DPose {
        let home=home(i)
        let destination=self.home(move.destination),h=profiles[i].height
        let direction:Float=approach==0 ? (destination.x>home.x ? 1:-1):approach
        let extraCapacity=Float(max(0,max(profiles[move.source].capacity,profiles[move.destination].capacity)-4))
        let standardSeparation:Float=0.10+0.18*extraCapacity
        let travelClearance=(profiles.map(\.height).max() ?? 2.35)+0.35
        let tilt:Float
        if let cutoff { tilt=stopAngle*(1-labSmooth((time-cutoff)/motion.upright)) }
        else { tilt=min(2.25,max(0,time-motion.tiltStart)*motion.tiltRate)*direction }
        let lowLip=destination+SIMD2(-direction*(approach==0 ? standardSeparation:max(0.46,standardSeparation)),profiles[move.destination].height+1.10)
        let highLip=SIMD2(approach==0 ? lowLip.x:destination.x-direction*1.05,travelClearance+h)
        let lip:SIMD2<Float>
        if let cutoff {
            let stoppedLip=simd_mix(highLip,lowLip,SIMD2(repeating:labSmooth((abs(stopAngle)-0.55)/0.95)))
            lip=simd_mix(stoppedLip,highLip,SIMD2(repeating:labSmooth((time-cutoff)/motion.upright)))
        } else { lip=simd_mix(highLip,lowLip,SIMD2(repeating:labSmooth((abs(tilt)-0.55)/0.95))) }
        let raised=home+SIMD2(0,travelClearance)
        let rotation=Lab2DPose(base:.zero,angle:tilt)
        let positioned=lip-rotation.rotate(SIMD2(0,h))
        var base=simd_mix(home,raised,SIMD2(repeating:labLiftProgress(time/motion.lift)))
        if time>=motion.lift { base=simd_mix(raised,positioned,SIMD2(repeating:labSmooth((time-motion.lift)/motion.travel))) }
        if let cutoff,time-cutoff>=motion.upright {
            let start=highLip-SIMD2(0,h),t=time-cutoff-motion.upright
            base=simd_mix(start,raised,SIMD2(repeating:labSmooth(t/motion.returnTravel)))
            if t>=motion.returnTravel { base=simd_mix(raised,home,SIMD2(repeating:labSmooth((t-motion.returnTravel)/motion.lower))) }
        }
        // Keep the entire silhouette above the board while crossing other vials.
        // The final descent happens only after the source is back over its own home.
        if time>=motion.lift && (cutoff == nil || time-cutoff!<motion.upright+motion.returnTravel) {
            var bottom:Float=0
            for k in 0...32 {
                let y=Float(k)/32*h
                bottom=min(bottom,cos(tilt)*y-abs(sin(tilt))*profiles[i].radius(y))
            }
            base.y=max(base.y,(profiles.map(\.height).max() ?? 2.35)+0.14-bottom)
        }
        return Lab2DPose(base:base,angle:tilt)
    }
    mutating func install(_ game:LabBoardGame) {
        let preserve = !busy && self.game.state==game.state && !particles.isEmpty
        mixing=nil;mixFrom=[];mixTargets=[]
        displayPoses=[:];displayMoves=[];displayEnvelope=nil;displayStreamActive=nil
        transfers=[];groupMode=false;groupResults=[]
        self.game=game;self.game.cancel();time=0;cutoff=nil;targets=nil;accumulator=0;selected=[]
        cleanupPercent=0;arrived=0;departed=0;lastOutcome="";cpuMilliseconds=0
        if preserve { return }
        profiles=zip(LabBoardLayout.profiles(capacities:game.state.capacities),game.state.capacities).map {
            Lab2DProfile($0.0,capacity:$0.1)
        }
        materialTimes=Array(repeating:0,count:profiles.count)
        surfaces=Array(repeating:Lab2DSurfaceState(),count:profiles.count);splashes=[]
        particles=seed(game.state);links=Array(repeating:-1,count:particles.count)
        // Relax the deterministic area-stratified seed without advancing a game move.
        for _ in 0..<240 { solve(active:Set(game.state.stacks.indices),dt:Self.step,poses:profiles.indices.map { pose($0) }) }
        for i in particles.indices { particles[i].velocity = .zero }
    }
    mutating func beginMix(_ transition:LabMixTransition) {
        mixFrom=particles
        let final=LabFluid2D(game:LabBoardGame(state:transition.after))
        mixTargets=final.particles
        // Both arrays are stably sorted by parcel; material identities survive mixing.
        mixing=transition
    }
    mutating func showMix(_ transition:LabMixTransition) {
        mixing=transition
        let output=transition.output,origin=SIMD3(home(output).x,Float(0),Float(0)),profile=profiles[output].source,parcels=transition.parcels
        for i in particles.indices where parcels.contains(particles[i].parcel) {
            let from=mixFrom[i],target=mixTargets[i]
            let phase=Float(i%Self.particlesPerUnit)/Float(Self.particlesPerUnit)
            let sample=transition.position(from:SIMD3(from.position.x,from.position.y,0),to:SIMD3(target.position.x,target.position.y,0),origin:origin,profile:profile,phase:phase)
            particles[i].position=SIMD2(sample.point.x,sample.point.y)
            particles[i].owner=sample.arrived ? output:(sample.started ? -1:from.owner)
            particles[i].inBulk=sample.arrived || !sample.started
            particles[i].velocity = .zero
        }
    }
    mutating func finishMix(_ game:LabBoardGame) {
        let parcels=mixing?.parcels ?? []
        for i in particles.indices where parcels.contains(particles[i].parcel) {particles[i]=mixTargets[i]}
        self.game=game;mixing=nil;mixFrom=[];mixTargets=[]
    }
    /// Reuse the settled particles without reseeding or relaxing at touch-down.
    mutating func adoptConcurrent(_ game:LabBoardGame,vessels:Set<Int>) {
        displayPoses=[:];displayMoves=[];displayEnvelope=nil;displayStreamActive=nil
        self.game=game;self.game.cancel();install(game)
        // Foreign airborne particles must not be captured by this lane's funnel.
        // They are rendered from their own lane, while this solver sees them at rest.
        let owned=Set(vessels.flatMap { game.state.stacks[$0] }),stable=seed(game.state)
        for i in particles.indices where !owned.contains(particles[i].parcel) { particles[i]=stable[i] }
    }
    mutating func setDisplayGame(_ game:LabBoardGame) { self.game=game }
    mutating func compose(_ lanes:[Lab2DLane],game:LabBoardGame) {
        self.game=game;displayPoses=[:];displayMoves=[];displayEnvelope=0;displayStreamActive=false;splashes=[]
        cpuMilliseconds=lanes.reduce(0) { $0+$1.engine.cpuMilliseconds }
        arrived=lanes.reduce(0) { $0+$1.engine.arrived };departed=lanes.reduce(0) { $0+$1.engine.departed }
        for lane in lanes {
            for i in particles.indices where lane.parcels.contains(particles[i].parcel) { particles[i]=lane.engine.particles[i] }
            for owner in [lane.item.move.source,lane.item.move.destination] {
                materialTimes[owner]=lane.engine.materialTimes[owner];surfaces[owner]=lane.engine.surfaces[owner]
            }
            splashes+=lane.engine.splashes
            if lane.engine.busy {
                displayStreamActive=(displayStreamActive ?? false) || lane.engine.streamActive
                displayMoves.append(lane.item.move);displayPoses[lane.item.move.source]=lane.engine.pose(lane.item.move.source)
                displayEnvelope=max(displayEnvelope ?? 0,lane.engine.surfaceEnvelope)
            }
        }
    }
    mutating func joinGroup(_ item:LabPourReservation,game:LabBoardGame,display:LabFluid2D)->Bool {
        guard game.state.applyingReserved(item.move) != nil else { return false }
        self.game=game;groupMode=true;displayPoses=[:];displayMoves=[]
        refreshForeignParticles(game,joining:item.move)
        let ids=Set(game.state.stacks[item.move.source])
        for i in particles.indices where ids.contains(particles[i].parcel) { particles[i]=display.particles[i] }
        transfers.append(Lab2DTransfer(item:item,sourceParcels:ids,before:particles))
        selected=Set(groupMoves.flatMap(\.parcels));return true
    }
    private mutating func refreshForeignParticles(_ game:LabBoardGame,joining:LabBoardMove?=nil) {
        let moves=groupMoves+[joining].compactMap {$0}
        let owners=Set(moves.flatMap {[$0.source,$0.destination]})
        let owned=Set(owners.flatMap {game.state.stacks[$0]}+moves.flatMap(\.parcels)),stable=seed(game.state)
        for i in particles.indices where !owned.contains(particles[i].parcel) {particles[i]=stable[i]}
    }
    mutating func synchronizeGroup(_ game:LabBoardGame) {
        if self.game.state != game.state {refreshForeignParticles(game)}
        self.game=game;groupResults=[]
    }
    mutating func composeGroups(_ engines:[LabFluid2D],game:LabBoardGame) {
        self.game=game;displayPoses=[:];displayMoves=[];displayEnvelope=0;displayStreamActive=false;splashes=[]
        cpuMilliseconds=0;arrived=0;departed=0;cleanupPercent=0
        for engine in engines {
            // Every receiver has one owner, including its newly arrived parcels.
            let owners=Set(engine.groupMoves.flatMap { [$0.source,$0.destination] }+engine.groupResults.flatMap { $0.vessels })
            let ids=Set(owners.flatMap { engine.game.state.stacks[$0] }+engine.groupMoves.flatMap(\.parcels))
            for i in particles.indices where ids.contains(particles[i].parcel) { particles[i]=engine.particles[i] }
            for owner in owners { materialTimes[owner]=engine.materialTimes[owner];surfaces[owner]=engine.surfaces[owner] }
            splashes+=engine.splashes;cpuMilliseconds+=engine.cpuMilliseconds;arrived+=engine.arrived;departed+=engine.departed
            cleanupPercent=max(cleanupPercent,engine.cleanupPercent)
            for move in engine.groupMoves { displayMoves.append(move);displayPoses[move.source]=engine.pose(move.source) }
            displayStreamActive=(displayStreamActive ?? false) || engine.streamActive
            displayEnvelope=max(displayEnvelope ?? 0,engine.surfaceEnvelope)
        }
    }
    private mutating func tickGroup() {
        let old=profiles.indices.map { pose($0) };time+=Self.step
        for i in transfers.indices { transfers[i].time+=Self.step }
        let poses=profiles.indices.map { pose($0) }
        let sources=Set(groupMoves.map(\.source)),receivers=Set(groupMoves.map(\.destination))
        var active=sources
        for receiver in receivers where transfers.contains(where:{$0.item.move.destination==receiver && $0.arrived>0}) { active.insert(receiver) }
        for owner in active {
            materialTimes[owner]+=Self.step
            let material=Lab2DMaterial.forColor(surfaces[owner].color)
            surfaces[owner].phase+=Self.step*material.frequency;surfaces[owner].energy*=exp(-material.damping*Self.step)
        }
        for i in splashes.indices { splashes[i].age+=Self.step };splashes.removeAll {$0.age>0.42}
        for i in particles.indices where sources.contains(particles[i].owner) {
            let owner=particles[i].owner
            particles[i].position=poses[owner].world(old[owner].local(particles[i].position))
        }
        solve(active:active,dt:Self.step,poses:poses)
        var finished:[Int]=[]
        for j in transfers.indices {
            var job=transfers[j];let move=job.item.move,count=move.amount*Self.particlesPerUnit,ids=Set(move.parcels)
            job.arrived=particles.filter {ids.contains($0.parcel) && $0.owner==move.destination}.count
            job.departed=particles.filter {ids.contains($0.parcel) && $0.owner != move.source}.count
            if job.cutoff==nil,job.arrived>=count-Int(Float(count)*0.05),job.departed>=count-1 {
                job.cutoff=job.time;job.angle=poses[move.source].angle
            }
            var success:Bool?
            if job.cutoff==nil,job.time>12 { success=false }
            if let start=job.cleanupStart {
                let f=labSmooth((job.time-start)/motion.cleanup)
                for (i,target) in job.targets {
                    particles[i].position=simd_mix(job.before[i].position,target.position,SIMD2(repeating:f))
                    if f>=1 { particles[i]=target }
                }
                if f>=1 { success=true }
            } else if let cutoff=job.cutoff,job.time-cutoff>motion.returned+motion.settle {
                let missing=count-job.arrived;job.cleanup=100*Float(missing)/Float(count)
                if missing<0 || missing>Int(Float(count)*0.05) { success=false }
                else if let next=game.state.applyingReserved(move) {
                    let packed=seed(next)
                    let visibleTop=particles.lazy.filter { $0.owner==move.destination && $0.inBulk }.map(\.position.y).max()
                    // Correct only this transfer's missing parcels. Other arrivals keep moving.
                    for i in particles.indices where ids.contains(particles[i].parcel) && particles[i].owner != move.destination {
                        var target=packed[i]
                        if let visibleTop { target.position.y=min(target.position.y,visibleTop) }
                        job.targets[i]=target
                    }
                    job.cleanupStart=job.time
                    // Only corrected indices use this pre-cleanup snapshot.
                    job=Lab2DTransfer(item:job.item,sourceParcels:job.sourceParcels,before:particles,time:job.time,cutoff:job.cutoff,angle:job.angle,arrived:job.arrived,departed:job.departed,cleanup:job.cleanup,targets:job.targets,cleanupStart:job.cleanupStart)
                } else { success=false }
            }
            if let success {
                let committed=success && game.commitReserved(move)
                if !committed { for i in particles.indices where job.sourceParcels.contains(particles[i].parcel) { particles[i]=job.before[i] } }
                for i in particles.indices where particles[i].owner==move.source { particles[i].velocity = .zero }
                groupResults.append(LabLaneResult(id:job.item.id,committed:committed,cleanup:job.cleanup,vessels:[move.source,move.destination],diagnostic:"arrived=\(job.arrived)/\(count) departed=\(job.departed) time=\(job.time)"))
                finished.append(j);cleanupPercent=job.cleanup
            }
            transfers[j]=job
        }
        for i in finished.reversed() { transfers.remove(at:i) }
        selected=Set(groupMoves.flatMap(\.parcels))
        arrived=transfers.reduce(0){$0+$1.arrived};departed=transfers.reduce(0){$0+$1.departed}
        displayStreamActive=transfers.contains {$0.departed>0 && $0.cutoff==nil}
        displayEnvelope=transfers.map { job in job.cutoff.map {1-labSmooth((job.time-$0)/max(0.01,motion.returned+motion.settle))} ?? 1 }.max() ?? 0
        if transfers.isEmpty { for owner in receivers { surfaces[owner].energy=0 };splashes=[] }
    }
    private func seed(_ state:LabBoardState)->[Lab2DParticle] {
        var result:[Lab2DParticle]=[]
        for owner in state.stacks.indices {
            for (layer,parcel) in state.stacks[owner].enumerated() {
                for k in 0..<Self.particlesPerUnit {
                    let unit=Float(layer)+(Float(k)+0.5)/Float(Self.particlesPerUnit)
                    let y=profiles[owner].level(unit)
                    let x=(Float(k)*0.61803398875).truncatingRemainder(dividingBy:1)*2-1
                    result.append(Lab2DParticle(position:home(owner)+SIMD2(x*max(0.02,profiles[owner].radius(y)-radius),y),owner:owner,parcel:parcel,color:state.visualDye(parcel)))
                }
            }
        }
        return result.sorted { $0.parcel == $1.parcel ? $0.position.y<$1.position.y:$0.parcel<$1.parcel }
    }
    @discardableResult mutating func begin(_ move:LabBoardMove,reserved:Bool=false)->Bool {
        guard !busy,game.state.move(from:move.source,to:move.destination)==move,game.begin(from:move.source,to:move.destination,reserved:reserved)==move else { return false }
        before=particles;time=0;cutoff=nil;targets=nil;accumulator=0;arrived=0;departed=0;cleanupPercent=0
        selected=Set(move.parcels);lastSplashTime = -1;splashSerial=0;splashes=[];return true
    }
    mutating func advance(deltaTime:Float,speed:Float=1) {
        guard busy else { return }
        let start=ProcessInfo.processInfo.systemUptime
        guard deltaTime.isFinite,speed.isFinite else { return }
        // Retain delayed frame time; bound worker batches without dropping debt.
        accumulator+=max(0,deltaTime)*max(0,speed)
        var steps=0
        while accumulator>=Self.step,busy,steps<12 { if groupMode { tickGroup() } else { tick() };accumulator-=Self.step;steps+=1 }
        cpuMilliseconds=(ProcessInfo.processInfo.systemUptime-start)*1000
    }
    private mutating func tick() {
        guard let move=game.pending else { return }
        let oldPoses=profiles.indices.map { pose($0) };time+=Self.step
        // These clocks advance only with an actual turn; Canvas stays still at rest.
        materialTimes[move.source]+=Self.step
        if arrived>0 { materialTimes[move.destination]+=Self.step }
        let poses=profiles.indices.map { pose($0) }
        for owner in [move.source,move.destination] {
            let material=Lab2DMaterial.forColor(surfaces[owner].color)
            surfaces[owner].phase+=Self.step*material.frequency
            surfaces[owner].energy*=exp(-material.damping*Self.step)
        }
        for i in splashes.indices { splashes[i].age+=Self.step }
        splashes.removeAll { $0.age>0.42 }
        if let targets {
            let f=labSmooth((time-targetStart)/motion.cleanup)
            for i in particles.indices { particles[i].position=simd_mix(before[i].position,targets[i].position,SIMD2(repeating:f)) }
            if f>=1 {
                particles=targets;_ = game.commit(move);self.targets=nil;cutoff=nil;lastOutcome="Move complete"
                surfaces[move.source].energy=0;surfaces[move.destination].energy=0;splashes=[]
            }
            return
        }
        // Carry liquid with vessel translation/rotation; gravity and neighbor forces
        // then redistribute it in the screen plane. Inactive vessels do no solver work.
        for i in particles.indices where particles[i].owner==move.source {
            let p=oldPoses[move.source].local(particles[i].position)
            particles[i].position=poses[move.source].world(p)
        }
        let received=particles.contains { $0.owner==move.destination && selected.contains($0.parcel) }
        solve(active:received ? [move.source,move.destination]:[move.source],dt:Self.step,poses:poses)
        let flowing=particles.filter { selected.contains($0.parcel) }
        arrived=flowing.filter { $0.owner==move.destination }.count
        departed=flowing.filter { $0.owner != move.source }.count
        let count=move.amount*Self.particlesPerUnit
        if cutoff==nil,arrived>=count-Int(Float(count)*0.05),departed>=count-1 {
            cutoff=time;stopAngle=poses[move.source].angle
            cleanupPercent=100*Float(count-arrived)/Float(count)
        }
        if cutoff==nil,time>12 {
            particles=before;game.cancel();surfaces=Array(repeating:Lab2DSurfaceState(),count:profiles.count);splashes=[];lastOutcome="Pour did not reach 95%; move restored.";return
        }
        if let cutoff,time-cutoff>motion.returned+motion.settle {
            guard let next=game.state.applying(move) else { return }
            cleanupPercent=100*Float(count-arrived)/Float(count)
            // Preserve the solved particle surface. Only missing transfer particles
            // are eligible for correction; successful arrivals never get repacked.
            let packed=seed(next)
            var byParcel:[Int:[Lab2DParticle]]=[:]
            for p in packed { byParcel[p.parcel,default:[]].append(p) }
            let visibleTop=particles.lazy.filter { $0.owner==move.destination && $0.inBulk }.map(\.position.y).max()
            var offsets:[Int:Int]=[:],final=particles
            for i in particles.indices {
                let p=particles[i],offset=offsets[p.parcel,default:0];offsets[p.parcel]=offset+1
                if selected.contains(p.parcel),p.owner != move.destination {
                    final[i]=byParcel[p.parcel]![offset]
                    if let visibleTop { final[i].position.y=min(final[i].position.y,visibleTop) }
                }
                final[i].velocity = .zero
            }
            before=particles;targets=final;targetStart=time
        }
    }
    private mutating func registerImpact(owner:Int,color:Int,point:SIMD2<Float>,velocity:SIMD2<Float>) {
        guard groupMode ? transfers.contains(where:{$0.item.move.destination==owner}):game.pending?.destination==owner else { return }
        if surfaces[owner].energy<0.003 { surfaces[owner].phase=0 }
        surfaces[owner].color=color
        surfaces[owner].impactX=surfaces[owner].impactX*0.75+point.x*0.25
        surfaces[owner].energy=min(1,surfaces[owner].energy+min(0.16,abs(velocity.y)*0.04+0.015))
        guard time-lastSplashTime>0.10,splashes.count<10,surfaceEnvelope>0.25 else { return }
        lastSplashTime=time;splashSerial+=1
        let material=Lab2DMaterial.forColor(color)
        let level=profiles[owner].level(bulkUnits[owner])
        for side:Float in [-1,1] {
            let variation=Float(splashSerial%3)*0.10
            splashes.append(Lab2DSplash(owner:owner,color:color,origin:SIMD2(point.x,level),velocity:SIMD2(side*(0.45+variation),material.splashSpeed+variation)))
        }
    }
    private func cell(_ p:SIMD2<Float>)->Int {
        let x=min(159,max(0,Int((p.x+12)/0.16))),y=min(95,max(0,Int((p.y+2)/0.16)))
        return x+y*160
    }
    private mutating func solve(active:Set<Int>,dt:Float,poses:[Lab2DPose]) {
        bulkUnits=Array(repeating:0,count:profiles.count)
        for p in particles where p.owner>=0 && p.inBulk { bulkUnits[p.owner]+=1/Float(Self.particlesPerUnit) }
        densityBands=[:];densityJoinedUnits=0
        if game.state.behavior.settlesByDensity,let move=game.pending {
            densityJoinedUnits=Float(particles.filter { $0.owner==move.destination && $0.inBulk && selected.contains($0.parcel) }.count)/Float(Self.particlesPerUnit)
            densityBands=game.state.densityReceiverBands(for:move,joinedUnits:densityJoinedUnits)
        }
        let ids=particles.indices.filter { active.contains(particles[$0].owner) || particles[$0].owner<0 }
        let previous=particles.map(\.position)
        for i in ids {
            // A receiving plume passes through lighter layers. Its displacement
            // is represented by the growing bands, not rigid particle contacts.
            if !densityBands.isEmpty,!particles[i].inBulk,particles[i].owner==game.pending?.destination {
                particles[i].velocity.y=min(-1.35,particles[i].velocity.y)
            }
            particles[i].velocity.y-=9.8*dt
            particles[i].velocity*=0.993
            let v=simd_length(particles[i].velocity)
            if v>5 { particles[i].velocity*=5/v }
            particles[i].position+=particles[i].velocity*dt
        }
        // A planar slice of round glass represents a depth of pi*r/2.
        // Match particle packing to that projected volume, especially through
        // broad bellies and narrow necks; fixed spacing underfills some shapes.
        var separations=Array(repeating:separation,count:particles.count)
        for i in ids where particles[i].owner>=0 && particles[i].inBulk {
            let owner=particles[i].owner,profile=profiles[owner]
            let y=poses[owner].local(particles[i].position).y
            let r=max(0.05,profile.radius(y))
            let unitVolume=profile.source.usableVolume/Float(profile.capacity)
            let projectedArea=unitVolume*2/(Float(Self.particlesPerUnit)*Float.pi*r)
            separations[i]=min(0.13,max(0.055,sqrt(projectedArea/0.8660254)*1.05))
        }
        for _ in 0..<5 {
            heads.withUnsafeMutableBufferPointer { $0.initialize(repeating:-1) }
            for i in ids { let c=cell(particles[i].position);links[i]=heads[c];heads[c]=i }
            for i in ids {
                let c=cell(particles[i].position),cx=c%160,cy=c/160
                for dy in -1...1 { for dx in -1...1 {
                    guard cx+dx>=0,cx+dx<160,cy+dy>=0,cy+dy<96 else { continue }
                    var j=heads[c+dx+dy*160]
                    while j>=0 {
                        let crossing = !densityBands.isEmpty && particles[i].owner==game.pending?.destination && particles[i].inBulk != particles[j].inBulk
                        if j>i,particles[i].owner==particles[j].owner,!crossing {
                            let d=particles[i].position-particles[j].position,l2=simd_length_squared(d)
                            if l2>0.000001,l2<0.0225 {
                                let l=sqrt(l2),n=d/l
                                var correction:Float=0
                                let spacing=(separations[i]+separations[j])*0.5
                                if l<spacing { correction=(spacing-l)*0.48 }
                                else if particles[i].color==particles[j].color {
                                    let releasing = !particles[i].inBulk || !particles[j].inBulk || ((game.pending?.source==particles[i].owner || transfers.contains(where:{$0.item.move.source==particles[i].owner})) && (selected.contains(particles[i].parcel) || selected.contains(particles[j].parcel)))
                                    correction = -(releasing ? 0.00005:0.0015)*(1-l/0.15)
                                }
                                particles[i].position+=n*correction;particles[j].position-=n*correction
                            }
                        }
                        j=links[j]
                    }
                }}
            }
            for i in ids { constrain(i,poses:poses) }
        }
        for i in ids {
            let newVelocity=(particles[i].position-previous[i])/dt
            particles[i].velocity=simd_mix(particles[i].velocity,newVelocity,SIMD2(repeating:0.70))*0.985
        }
    }
    private mutating func constrain(_ i:Int,poses:[Lab2DPose]) {
        var p=particles[i]
        let transfer=groupMode ? transfers.first(where:{$0.item.move.source==p.owner || $0.item.move.parcels.contains(p.parcel)}):nil
        let move=groupMode ? transfer?.item.move:game.pending
        if p.owner<0 {
            if let move {
                let destination=move.destination,profile=profiles[destination]
                var q=poses[destination].local(p.position)
                let above=q.y-profile.height
                if above > -0.08,above<1.25,abs(q.x)<profile.radius(profile.height)+0.85 {
                    let funnel=profile.radius(profile.height)-radius+max(0,above)*0.6
                    if abs(q.x)>funnel { q.x=copysign(funnel,q.x);p.position=poses[destination].world(q);p.velocity.x*=0.5 }
                }
                if q.y<=profile.height,q.y>=profile.height-0.22,abs(q.x)<=profile.radius(q.y)-radius*0.3 { p.owner=destination }
            }
            if p.position.y<radius { p.position.y=radius;p.velocity*=0.5 }
            particles[i]=p
            if p.owner<0 { return }
        }
        let owner=p.owner,profile=profiles[owner],pose=poses[owner]
        var q=pose.local(p.position)
        let outgoing=move?.source==owner && selected.contains(p.parcel) && (groupMode ? transfer?.cutoff==nil:cutoff==nil) && (transfer?.time ?? time)>motion.tiltStart
        if outgoing,q.y>profile.height,abs(q.x)<=profile.radius(profile.height)+radius {
            p.owner = -1;p.inBulk=false;bulkUnits[owner]-=1/Float(Self.particlesPerUnit);particles[i]=p;return
        }
        // Incoming droplets fall freely until they touch the liquid body. Only
        // joined particles contribute to its fill height; mouth entry is not a
        // teleport to the surface. The bound uses the same projected-volume units as rest.
        let densityReceiving = !densityBands.isEmpty && owner==move?.destination
        if !p.inBulk {
            let landingUnits:Float
            if densityReceiving,let move { landingUnits=Float(game.state.densityInsertionIndex(for:move))+densityJoinedUnits }
            else { landingUnits=bulkUnits[owner] }
            if q.y<=profile.level(landingUnits)+radius*1.4 {
                p.inBulk=true;bulkUnits[owner]+=1/Float(Self.particlesPerUnit)
                if densityReceiving { densityJoinedUnits+=1/Float(Self.particlesPerUnit) }
                else { registerImpact(owner:owner,color:p.color,point:q,velocity:p.velocity) }
            } else {
                q.y=max(radius,q.y)
                let r=max(radius,profile.radius(q.y)-radius)
                q.x=min(r,max(-r,q.x));p.position=pose.world(q);particles[i]=p;return
            }
        }
        var lower:Float=radius,upper=profile.height-radius
        var stack=game.state.stacks[owner]
        for incoming in groupMode ? groupMoves:[game.pending].compactMap({$0}) {
            if owner==incoming.destination { stack += incoming.parcels }
            if owner==incoming.source,!selected.contains(p.parcel) { stack.removeAll { selected.contains($0) } }
        }
        if let layer=stack.firstIndex(of:p.parcel) {
            // Same-color units share a band. Unlike dyes remain readable puzzle layers.
            var lo=layer,hi=layer+1
            while lo>0,game.state.visualDye(stack[lo-1])==p.color { lo-=1 }
            while hi<stack.count,game.state.visualDye(stack[hi])==p.color { hi+=1 }
            // A partial pour owns the top units, even when the retained fluid
            // has the same color. Keep that outgoing band above the remainder.
            if outgoing,let move { lo=max(lo,stack.count-move.amount) }
            lower=max(radius,profile.level(Float(lo))+radius*0.75)
            if !outgoing {
                var units=Float(hi)
                if move?.source != owner { units=min(units,bulkUnits[owner]) }
                upper=max(lower,min(upper,profile.level(units)-radius))
            }
        } else if let move,owner==move.destination {
            let stack=game.state.stacks[owner]
            var lo=stack.count
            while lo>0,game.state.visualDye(stack[lo-1])==p.color { lo-=1 }
            lower=max(radius,profile.level(Float(lo))+radius*0.75)
        }
        if densityReceiving,let band=densityBands[p.parcel] {
            lower=max(radius,profile.level(band.x)+radius*0.75)
            upper=max(lower,min(profile.height-radius,profile.level(band.y)-radius))
        }
        q.y=max(lower,q.y)
        if !outgoing { q.y=min(upper,q.y) }
        let r=max(radius,profile.radius(q.y)-radius)
        q.x=min(r,max(-r,q.x))
        p.position=pose.world(q);particles[i]=p
    }
}

/// The worker owns a value copy; UI snapshots share no mutable solver state.
actor Lab2DWorker {
    private var engine:LabFluid2D
    init(_ engine:LabFluid2D) { self.engine=engine }
    func replace(_ engine:LabFluid2D) { self.engine=engine }
    func advance(deltaTime:Float,speed:Float) -> LabFluid2D {
        engine.advance(deltaTime:deltaTime,speed:speed)
        return engine
    }
}

nonisolated struct Lab2DLane:Sendable {
    let item:LabPourReservation
    let parcels:Set<Int>
    var engine:LabFluid2D
    let initialMoves:Int
}
nonisolated struct LabLaneResult:Sendable {
    let id:Int,committed:Bool,cleanup:Float
    var vessels:[Int]=[]
    var diagnostic:String=""
}
nonisolated struct Lab2DConcurrentFrame:Sendable {
    var display:LabFluid2D
    let finished:[LabLaneResult]
}
actor LabConcurrent2DWorker {
    private var display:LabFluid2D
    private var groups:[Int:LabFluid2D]=[:]
    private var previous:(LabFluid2D,[Int:LabFluid2D])?
    init(_ display:LabFluid2D) { self.display=display }
    func advance(game:LabBoardGame,starts:[LabPourReservation],deltaTime:Float,speed:Float)->Lab2DConcurrentFrame {
        previous=(display,groups)
        for receiver in groups.keys { groups[receiver]!.synchronizeGroup(game) }
        var failed:[LabLaneResult]=[]
        for item in starts {
            let receiver=item.move.destination
            if groups[receiver]==nil {
                var engine=display;engine.adoptConcurrent(game,vessels:item.vessels);engine.synchronizeGroup(game)
                groups[receiver]=engine
            }
            if !groups[receiver]!.joinGroup(item,game:game,display:display) { failed.append(LabLaneResult(id:item.id,committed:false,cleanup:0)) }
        }
        for receiver in groups.keys { groups[receiver]!.advance(deltaTime:deltaTime,speed:speed) }
        display.composeGroups(groups.keys.sorted().compactMap {groups[$0]},game:game)
        let done=groups.values.flatMap(\.groupResults)
        groups=groups.filter {!$0.value.groupMoves.isEmpty}
        return Lab2DConcurrentFrame(display:display,finished:failed+done)
    }
    func rollbackLastAdvance() { if let previous { display=previous.0;groups=previous.1 };previous=nil }
}
