import Foundation
import simd
@main struct Validate2D {
    static func overlaps(_ engine:LabFluid2D,source:Int)->Int {
        func polygon(_ i:Int)->[SIMD2<Float>] {
            let p=engine.profiles[i],pose=engine.pose(i)
            return (0...24).map { let y=Float($0)/24*p.height;return pose.world(SIMD2(p.radius(y),y)) } + (0...24).reversed().map { let y=Float($0)/24*p.height;return pose.world(SIMD2(-p.radius(y),y)) }
        }
        func cross(_ a:SIMD2<Float>,_ b:SIMD2<Float>)->Float { a.x*b.y-a.y*b.x }
        let a=polygon(source)
        for i in engine.profiles.indices where i != source {
            let b=polygon(i)
            if a.map(\.x).max()!<b.map(\.x).min()! || b.map(\.x).max()!<a.map(\.x).min()! || a.map(\.y).max()!<b.map(\.y).min()! || b.map(\.y).max()!<a.map(\.y).min()! { continue }
            for k in a.indices { for j in b.indices {
                let p=a[k],q=a[(k+1)%a.count],r=b[j],s=b[(j+1)%b.count]
                if cross(q-p,r-p)*cross(q-p,s-p)<0 && cross(s-r,p-r)*cross(s-r,q-r)<0 { return 1 }
            }}
        }
        return 0
    }
    static func surface(_ engine:LabFluid2D,_ owner:Int)->Float {
        guard let top=engine.particles.filter({ $0.owner==owner && $0.inBulk }).map({ $0.position.y-engine.home(owner).y }).max() else { return 0 }
        return top+engine.radius
    }
    static func main() throws {
        let args=CommandLine.arguments
        let puzzle=LabBoardPuzzle(rawValue:args.dropFirst().first ?? "greenArrival") ?? .greenArrival
        var engine=LabFluid2D(game:LabBoardGame(state:puzzle.initial))
        engine.quickMotion = !args.contains("--relaxed")
        let frameRate=args.contains("--30fps") ? 30.0:60.0
        let speed:Float=engine.quickMotion ? 1.6:1.0
        var rows:[[String:Any]]=[]
        for color in Set(puzzle.initial.colors).sorted() {
            let surface=Lab2DSurfaceState(energy:1,phase:1.3,impactX:0,color:color)
            let samples=(0...128).map { surface.offset(x:Float($0)/64-1,halfWidth:1,envelope:1) }
            let mean=(samples.reduce(0,+)-(samples.first!+samples.last!)/2)/128
            precondition(abs(mean)<0.00001 && samples.allSatisfy { abs($0)<=Lab2DMaterial.forColor(color).waveHeight },"Ripple changed mean level or exceeded its height bound")
        }
        guard let route=puzzle.initial.solution() else { fatalError("No route") }
        for (index,move) in route.enumerated() {
            let original=engine.particles,originalClocks=engine.materialTimes,originalSurfaces=engine.surfaces
            let initialLevel=surface(engine,move.destination)
            var activationShift:Float=0,preCleanupLevel:Float?,preCleanupParticles:[Lab2DParticle]?
            var prematureMotion=false
            let expected=engine.game.state.applying(move)!
            guard engine.begin(move) else { fatalError("Begin failed") }
            var steps=0,times:[Double]=[],intersections=0
            var peakEnergy:Float=0,maxSplashes=0
            var firstDeparture:Float?,lastDeparture:Float?,maxDepartureBatch=0,previousDeparted=0
            while engine.busy,steps<2000 {
                engine.advance(deltaTime:Float(1/frameRate),speed:speed);steps+=1;times.append(engine.cpuMilliseconds)
                peakEnergy=max(peakEnergy,engine.surfaces[move.destination].energy);maxSplashes=max(maxSplashes,engine.splashes.count)
                precondition(engine.splashes.count<=10 && engine.surfaces.allSatisfy { $0.energy>=0 && $0.energy<=1 },"Unbounded effects")
                if engine.phase=="Final settling" { precondition(engine.surfaceEnvelope==0,"Surface effect still visible at cleanup") }
                let batch=engine.departed-previousDeparted
                if batch>0 { if firstDeparture==nil { firstDeparture=engine.time };lastDeparture=engine.time }
                maxDepartureBatch=max(maxDepartureBatch,batch);previousDeparted=engine.departed
                if engine.time<0.4 {
                    activationShift=max(activationShift,abs(surface(engine,move.destination)-initialLevel))
                    if original.indices.contains(where:{ original[$0].owner==move.destination && original[$0] != engine.particles[$0] }) { prematureMotion=true }
                }
                if preCleanupLevel==nil,engine.phase=="Final settling" { preCleanupLevel=surface(engine,move.destination);preCleanupParticles=engine.particles }
                if engine.busy { let hit=overlaps(engine,source:move.source);if hit>0 && intersections==0 { print("Intersection at sim time \(engine.time), source pose \(engine.pose(move.source))") };intersections+=hit }
                guard engine.particles.allSatisfy({ $0.position.x.isFinite && $0.position.y.isFinite }) else { fatalError("Nonfinite") }
            }
            let unaffected=original.indices.filter { original[$0].owner != move.source && original[$0].owner != move.destination }
            let stationary=unaffected.allSatisfy { original[$0] == engine.particles[$0] }
            let inactiveMaterials=originalClocks.indices.filter { $0 != move.source && $0 != move.destination }.allSatisfy { originalClocks[$0]==engine.materialTimes[$0] && originalSurfaces[$0]==engine.surfaces[$0] }
            let settledClocks=engine.materialTimes,settledParticles=engine.particles,settledSurfaces=engine.surfaces
            engine.advance(deltaTime:0.1,speed:speed)
            let idleFrozen=engine.materialTimes==settledClocks && engine.particles==settledParticles && engine.surfaces==settledSurfaces && engine.splashes.isEmpty && engine.surfaceEnvelope==0
            let finalLevel=surface(engine,move.destination)
            let cleanupShift=abs(finalLevel-(preCleanupLevel ?? finalLevel))
            let desiredLevel=engine.profiles[move.destination].level(Float(expected.stacks[move.destination].count))
            let fillError=abs(finalLevel-desiredLevel)/engine.profiles[move.destination].height
            let preserved=preCleanupParticles.map { pre in
                pre.indices.allSatisfy { i in
                    pre[i].owner != move.destination || pre[i].position==engine.particles[i].position
                }
            } ?? false
            let passed=engine.game.state==expected && stationary && engine.cleanupPercent<=5 && intersections==0 && !prematureMotion && activationShift<0.001 && cleanupShift<0.02 && fillError<0.05 && preserved && inactiveMaterials && idleFrozen
            times.sort()
            let row:[String:Any]=["peakSurfaceEnergy":peakEnergy,"maximumSplashCount":maxSplashes,"move":index+1,"source":move.source,"destination":move.destination,"units":move.amount,"seconds":Double(steps)/frameRate,"departureSpanSimSeconds":(lastDeparture ?? 0)-(firstDeparture ?? 0),"maxDepartureBatch":maxDepartureBatch,"inactiveMaterialsFrozen":inactiveMaterials,"idleFrozen":idleFrozen,"cleanupPercent":engine.cleanupPercent,"arrived":engine.arrived,"departed":engine.departed,"cpuMedianMS":times[times.count/2],"cpuP95MS":times[min(times.count-1,Int(Double(times.count)*0.95))],"passed":passed,"stationary":stationary,"vialIntersectionFrames":intersections,"activationLevelShift":activationShift,"cleanupLevelShift":cleanupShift,"fillHeightErrorPercent":fillError*100,"settledArrivalsPreserved":preserved,"outcome":engine.lastOutcome]
            rows.append(row)
            print(String(data:try JSONSerialization.data(withJSONObject:row,options:.sortedKeys),encoding:.utf8)!)
            fflush(stdout)
            if !passed { break }
        }
        let report:[String:Any]=["pace":engine.quickMotion ? "quick":"relaxed","frameRate":frameRate,"puzzle":puzzle.rawValue,"particleCount":engine.particles.count,"solved":engine.game.state.solved,"moves":rows]
        try JSONSerialization.data(withJSONObject:report,options:[.prettyPrinted,.sortedKeys]).write(to:URL(fileURLWithPath:args.count>2 ? args[2]:"/private/tmp/vials-2d-\(puzzle.rawValue).json"))
        if !engine.game.state.solved { exit(1) }
    }
}
