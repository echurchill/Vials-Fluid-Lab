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
    static func main() throws {
        let args=CommandLine.arguments
        let puzzle=LabBoardPuzzle(rawValue:args.dropFirst().first ?? "greenArrival") ?? .greenArrival
        let engine=LabFluid2D(game:LabBoardGame(state:puzzle.initial))
        var rows:[[String:Any]]=[]
        guard let route=puzzle.initial.solution() else { fatalError("No route") }
        for (index,move) in route.enumerated() {
            let original=engine.particles
            let expected=engine.game.state.applying(move)!
            guard engine.begin(move) else { fatalError("Begin failed") }
            var steps=0,times:[Double]=[],intersections=0
            while engine.busy,steps<2000 {
                engine.advance(deltaTime:1/60,speed:1.6);steps+=1;times.append(engine.cpuMilliseconds)
                if engine.busy { let hit=overlaps(engine,source:move.source);if hit>0 && intersections==0 { print("Intersection at sim time \(engine.time), source pose \(engine.pose(move.source))") };intersections+=hit }
                guard engine.particles.allSatisfy({ $0.position.x.isFinite && $0.position.y.isFinite }) else { fatalError("Nonfinite") }
            }
            let unaffected=original.indices.filter { original[$0].owner != move.source && original[$0].owner != move.destination }
            let stationary=unaffected.allSatisfy { original[$0] == engine.particles[$0] }
            let passed=engine.game.state==expected && stationary && engine.cleanupPercent<=5 && intersections==0
            times.sort()
            let row:[String:Any]=["move":index+1,"source":move.source,"destination":move.destination,"units":move.amount,"seconds":Double(steps)/60,"cleanupPercent":engine.cleanupPercent,"arrived":engine.arrived,"departed":engine.departed,"cpuMedianMS":times[times.count/2],"cpuP95MS":times[min(times.count-1,Int(Double(times.count)*0.95))],"passed":passed,"stationary":stationary,"vialIntersectionFrames":intersections,"outcome":engine.lastOutcome]
            rows.append(row)
            print(String(data:try JSONSerialization.data(withJSONObject:row,options:.sortedKeys),encoding:.utf8)!)
            fflush(stdout)
            if !passed { break }
        }
        let report:[String:Any]=["puzzle":puzzle.rawValue,"particleCount":engine.particles.count,"solved":engine.game.state.solved,"moves":rows]
        try JSONSerialization.data(withJSONObject:report,options:[.prettyPrinted,.sortedKeys]).write(to:URL(fileURLWithPath:args.count>2 ? args[2]:"/private/tmp/vials-2d-\(puzzle.rawValue).json"))
        if !engine.game.state.solved { exit(1) }
    }
}
