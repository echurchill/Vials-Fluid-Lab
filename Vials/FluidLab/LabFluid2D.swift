import Foundation
import simd

/// Planar, equal-area particles. No depth coordinate or 3D neighbor search.
/// Puzzle layers and the receiving-mouth guide are deliberate game assists.
struct Lab2DProfile {
    let source:LabVesselProfile
    let scale:Float
    let areas:[Float]
    var height:Float { source.height }
    var area:Float { areas.last! }
    init(_ source:LabVesselProfile,area:Float) {
        self.source=source
        let dy=(source.height-0.20)/128
        var raw:[Float]=[0]
        for i in 1...128 { raw.append(raw.last!+(source.radius(at:Float(i-1)*dy)+source.radius(at:Float(i)*dy))*dy) }
        let factor=area/raw.last!;scale=factor;areas=raw.map { $0*factor }
    }
    func radius(_ y:Float)->Float { source.radius(at:y)*scale }
    func level(_ units:Float)->Float {
        let target=min(area,max(0,units*area/4))
        let i=min(127,max(0,(areas.firstIndex { $0>=target } ?? 128)-1))
        let fraction=(target-areas[i])/max(0.00001,areas[i+1]-areas[i])
        return (Float(i)+fraction)*(height-0.20)/128
    }
}
struct Lab2DPose {
    var base:SIMD2<Float>
    var angle:Float=0
    func rotate(_ p:SIMD2<Float>)->SIMD2<Float> { SIMD2(cos(angle)*p.x+sin(angle)*p.y,-sin(angle)*p.x+cos(angle)*p.y) }
    func world(_ p:SIMD2<Float>)->SIMD2<Float> { base+rotate(p) }
    func local(_ p:SIMD2<Float>)->SIMD2<Float> { let d=p-base;return SIMD2(cos(angle)*d.x-sin(angle)*d.y,sin(angle)*d.x+cos(angle)*d.y) }
}
struct Lab2DParticle:Equatable {
    var position:SIMD2<Float>
    var velocity=SIMD2<Float>.zero
    var owner:Int
    var inBulk=true // False while falling through air or the empty part of a receiver.
    let parcel:Int
    let color:Int
}
final class LabFluid2D {
    static let particlesPerUnit=96
    static let step:Float=1/120
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
    private var before:[Lab2DParticle]=[]
    private var targets:[Lab2DParticle]?
    private var targetStart:Float=0
    private var stopAngle:Float=0
    private var heads=[Int](repeating:-1,count:160*96)
    private var links:[Int]=[]
    private var selected:Set<Int>=[]
    private var bulkUnits:[Float]=[]
    var busy:Bool { game.pending != nil }
    var phase:String {
        if targets != nil { return "Final settling" }
        if cutoff != nil { return "Returning the vial" }
        if time<0.5 { return "Lifting the vial" }
        if time<0.95 { return "Moving into position" }
        return "Pouring"
    }
    init(game:LabBoardGame=LabBoardGame()) { install(game) }
    func home(_ i:Int)->SIMD2<Float> { SIMD2((Float(i)-Float(profiles.count-1)/2)*2.2,0) }
    func pose(_ i:Int)->Lab2DPose {
        let home=home(i)
        guard let move=game.pending,i==move.source else { return Lab2DPose(base:home) }
        let destination=self.home(move.destination),h=profiles[i].height
        let direction:Float=destination.x>home.x ? 1:-1
        let tilt:Float
        if let cutoff { tilt=stopAngle*(1-labSmooth((time-cutoff)/0.7)) }
        else { tilt=min(2.25,max(0,time-0.95)*0.78)*direction }
        let lowLip=destination+SIMD2(-direction*0.10,profiles[move.destination].height+1.10)
        let highLip=SIMD2(lowLip.x,2.65+h)
        let lip:SIMD2<Float>
        if let cutoff {
            let stoppedLip=simd_mix(highLip,lowLip,SIMD2(repeating:labSmooth((abs(stopAngle)-0.55)/0.95)))
            lip=simd_mix(stoppedLip,highLip,SIMD2(repeating:labSmooth((time-cutoff)/0.7)))
        } else { lip=simd_mix(highLip,lowLip,SIMD2(repeating:labSmooth((abs(tilt)-0.55)/0.95))) }
        let raised=home+SIMD2(0,2.65)
        let rotation=Lab2DPose(base:.zero,angle:tilt)
        let positioned=lip-rotation.rotate(SIMD2(0,h))
        var base=simd_mix(home,raised,SIMD2(repeating:labSmooth(time/0.5)))
        if time>=0.5 { base=simd_mix(raised,positioned,SIMD2(repeating:labSmooth((time-0.5)/0.45))) }
        if let cutoff,time-cutoff>=0.7 {
            let start=highLip-SIMD2(0,h),t=time-cutoff-0.7
            base=simd_mix(start,raised,SIMD2(repeating:labSmooth(t/0.45)))
            if t>=0.45 { base=simd_mix(raised,home,SIMD2(repeating:labSmooth((t-0.45)/0.45))) }
        }
        // Keep the entire silhouette above the board while crossing other vials.
        // The final descent happens only after the source is back over its own home.
        if time>=0.5 && (cutoff == nil || time-cutoff!<1.15) {
            var bottom:Float=0
            for k in 0...32 {
                let y=Float(k)/32*h
                bottom=min(bottom,cos(tilt)*y-abs(sin(tilt))*profiles[i].radius(y))
            }
            base.y=max(base.y,2.35+0.14-bottom)
        }
        return Lab2DPose(base:base,angle:tilt)
    }
    func install(_ game:LabBoardGame) {
        let preserve = !busy && self.game.state==game.state && !particles.isEmpty
        self.game=game;self.game.cancel();time=0;cutoff=nil;targets=nil;accumulator=0;selected=[]
        cleanupPercent=0;arrived=0;departed=0;lastOutcome="";cpuMilliseconds=0
        if preserve { return }
        profiles=LabBoardLayout.profiles(count:game.state.stacks.count).map { Lab2DProfile($0,area:2.12) }
        particles=seed(game.state);links=Array(repeating:-1,count:particles.count)
        // Relax the deterministic area-stratified seed without advancing a game move.
        for _ in 0..<240 { solve(active:Set(game.state.stacks.indices),dt:Self.step,poses:profiles.indices.map { pose($0) }) }
        for i in particles.indices { particles[i].velocity = .zero }
    }
    private func seed(_ state:LabBoardState)->[Lab2DParticle] {
        var result:[Lab2DParticle]=[]
        for owner in state.stacks.indices {
            for (layer,parcel) in state.stacks[owner].enumerated() {
                for k in 0..<Self.particlesPerUnit {
                    let unit=Float(layer)+(Float(k)+0.5)/Float(Self.particlesPerUnit)
                    let y=profiles[owner].level(unit)
                    let x=(Float(k)*0.61803398875).truncatingRemainder(dividingBy:1)*2-1
                    result.append(Lab2DParticle(position:home(owner)+SIMD2(x*max(0.02,profiles[owner].radius(y)-radius),y),owner:owner,parcel:parcel,color:state.colors[parcel]))
                }
            }
        }
        return result.sorted { $0.parcel == $1.parcel ? $0.position.y<$1.position.y:$0.parcel<$1.parcel }
    }
    @discardableResult func begin(_ move:LabBoardMove)->Bool {
        guard !busy,game.state.move(from:move.source,to:move.destination)==move,game.begin(from:move.source,to:move.destination)==move else { return false }
        before=particles;time=0;cutoff=nil;targets=nil;accumulator=0;arrived=0;departed=0;cleanupPercent=0
        selected=Set(move.parcels);return true
    }
    func advance(deltaTime:Float,speed:Float=1) {
        guard busy else { return }
        let start=ProcessInfo.processInfo.systemUptime
        accumulator+=min(0.05,max(0,deltaTime))*speed
        while accumulator>=Self.step,busy { tick();accumulator-=Self.step }
        cpuMilliseconds=(ProcessInfo.processInfo.systemUptime-start)*1000
    }
    private func tick() {
        guard let move=game.pending else { return }
        let oldPoses=profiles.indices.map { pose($0) };time+=Self.step
        let poses=profiles.indices.map { pose($0) }
        if let targets {
            let f=labSmooth((time-targetStart)/0.35)
            for i in particles.indices { particles[i].position=simd_mix(before[i].position,targets[i].position,SIMD2(repeating:f)) }
            if f>=1 {
                particles=targets;_ = game.commit(move);self.targets=nil;cutoff=nil;lastOutcome="Move complete"
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
            particles=before;game.cancel();lastOutcome="Pour did not reach 95%; move restored.";return
        }
        if let cutoff,time-cutoff>2.15 {
            guard let next=game.state.applying(move) else { return }
            cleanupPercent=100*Float(count-arrived)/Float(count)
            // Preserve the solved particle surface. Only missing transfer particles
            // are eligible for correction; successful arrivals never get repacked.
            let packed=seed(next)
            var byParcel:[Int:[Lab2DParticle]]=[:]
            for p in packed { byParcel[p.parcel,default:[]].append(p) }
            var offsets:[Int:Int]=[:],final=particles
            for i in particles.indices {
                let p=particles[i],offset=offsets[p.parcel,default:0];offsets[p.parcel]=offset+1
                if selected.contains(p.parcel),p.owner != move.destination { final[i]=byParcel[p.parcel]![offset] }
                final[i].velocity = .zero
            }
            before=particles;targets=final;targetStart=time
        }
    }
    private func cell(_ p:SIMD2<Float>)->Int {
        let x=min(159,max(0,Int((p.x+12)/0.16))),y=min(95,max(0,Int((p.y+2)/0.16)))
        return x+y*160
    }
    private func solve(active:Set<Int>,dt:Float,poses:[Lab2DPose]) {
        bulkUnits=Array(repeating:0,count:profiles.count)
        for p in particles where p.owner>=0 && p.inBulk { bulkUnits[p.owner]+=1/Float(Self.particlesPerUnit) }
        let ids=particles.indices.filter { active.contains(particles[$0].owner) || particles[$0].owner<0 }
        let previous=particles.map(\.position)
        for i in ids {
            particles[i].velocity.y-=9.8*dt
            particles[i].velocity*=0.993
            let v=simd_length(particles[i].velocity)
            if v>5 { particles[i].velocity*=5/v }
            particles[i].position+=particles[i].velocity*dt
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
                        if j>i,particles[i].owner==particles[j].owner {
                            let d=particles[i].position-particles[j].position,l2=simd_length_squared(d)
                            if l2>0.000001,l2<0.0225 {
                                let l=sqrt(l2),n=d/l
                                var correction:Float=0
                                if l<separation { correction=(separation-l)*0.48 }
                                else if particles[i].color==particles[j].color { correction = -0.0015*(1-l/0.15) }
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
    private func constrain(_ i:Int,poses:[Lab2DPose]) {
        var p=particles[i]
        if p.owner<0 {
            if let move=game.pending {
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
        let outgoing=game.pending?.source==owner && selected.contains(p.parcel) && cutoff==nil && time>0.95
        if outgoing,q.y>profile.height,abs(q.x)<=profile.radius(profile.height)+radius {
            p.owner = -1;p.inBulk=false;bulkUnits[owner]-=1/Float(Self.particlesPerUnit);particles[i]=p;return
        }
        // Incoming droplets fall freely until they touch the liquid body. Only
        // joined particles contribute to its fill height; mouth entry is not a
        // teleport to the surface. The bound uses the same equal-area units as rest.
        if !p.inBulk {
            if q.y<=profile.level(bulkUnits[owner])+radius*1.4 {
                p.inBulk=true;bulkUnits[owner]+=1/Float(Self.particlesPerUnit)
            } else {
                q.y=max(radius,q.y)
                let r=max(radius,profile.radius(q.y)-radius)
                q.x=min(r,max(-r,q.x));p.position=pose.world(q);particles[i]=p;return
            }
        }
        var lower:Float=radius,upper=profile.height-radius
        var stack=game.state.stacks[owner]
        if let move=game.pending {
            if owner==move.destination { stack += move.parcels }
            if owner==move.source,!selected.contains(p.parcel) { stack.removeAll { selected.contains($0) } }
        }
        if let layer=stack.firstIndex(of:p.parcel) {
            // Same-color units share a band. Unlike dyes remain readable puzzle layers.
            var lo=layer,hi=layer+1
            while lo>0,game.state.colors[stack[lo-1]]==p.color { lo-=1 }
            while hi<stack.count,game.state.colors[stack[hi]]==p.color { hi+=1 }
            lower=max(radius,profile.level(Float(lo))+radius*0.75)
            if !outgoing {
                var units=Float(hi)
                if game.pending?.source != owner { units=min(units,bulkUnits[owner]) }
                upper=max(lower,min(upper,profile.level(units)-radius))
            }
        } else if let move=game.pending,owner==move.destination {
            let stack=game.state.stacks[owner]
            var lo=stack.count
            while lo>0,game.state.colors[stack[lo-1]]==p.color { lo-=1 }
            lower=max(radius,profile.level(Float(lo))+radius*0.75)
        }
        q.y=max(lower,q.y)
        if !outgoing { q.y=min(upper,q.y) }
        let r=max(radius,profile.radius(q.y)-radius)
        q.x=min(r,max(-r,q.x))
        p.position=pose.world(q);particles[i]=p
    }
}
