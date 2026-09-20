import Foundation
import simd

struct LabBoardBand { var range: SIMD4<Float> } // bounds, enabled, coordinate space (1 = vial-local Y)

/// Motion timing is independent of the fixed 120 Hz fluid solver.
enum LabBoardTiming {
    static let preparation:Float = 0.10
    static let lift:Float = 0.50
    static let travel:Float = 0.45
    static let tiltStart = lift + travel
    static let stop:Float = 0.20
    static let upright:Float = 0.50
    static let untilted = stop + upright
    static let returnTravel:Float = 0.45
    static let lower:Float = 0.45
    static let returned = returnTravel + lower
    static let settling:Float = 0.20
    static let cleanup:Float = 0.35 // retains the 0.3-second particle fade
    static let approachRate:Float = 1.10
    static let pouringRate:Float = 0.80
    static let timeout:Float = 12
}

struct LabBoardLayout {
    static let homes:[SIMD3<Float>]=[-3.3,-1.1,1.1,3.3].map { SIMD3($0,0.18,0) }
    static func homes(count:Int) -> [SIMD3<Float>] {
        (0..<count).map { SIMD3((Float($0)-Float(count-1)/2)*2.2,0.18,0) }
    }
    nonisolated static func profiles(count:Int = 4) -> [LabVesselProfile] {
        profiles(capacities:Array(repeating:4,count:count))
    }
    nonisolated static func profiles(capacities:[Int]) -> [LabVesselProfile] {
        let tube:[(Float,Float)]=[(0,0.24),(0.025,0.35),(0.085,0.47),(1,0.47)]
        let bulb:[(Float,Float)]=[(0,0.28),(0.04,0.47),(0.16,0.70),(0.34,0.74),(0.49,0.61),(0.66,0.30),(0.74,0.32),(0.87,0.32),(0.94,0.40),(1,0.54)]
        let specs:[(String,[(Float,Float)])]=[("Rounded vial",tube),("Bulb flask",bulb),
            ("Tapered flask",[(0,0.58),(0.07,0.64),(0.52,0.50),(0.80,0.31),(0.91,0.34),(1,0.54)]),
            ("Pear flask",[(0,0.25),(0.06,0.48),(0.27,0.69),(0.49,0.59),(0.73,0.32),(0.91,0.32),(1,0.54)])]
        let reference=LabVesselProfile(name:"Rounded vial",height:2.35,knots:tube).usableVolume
        return capacities.enumerated().map { index,capacity in
            let spec=specs[index % specs.count]
            let volumeScale=Float(capacity)/4
            // Share capacity growth between height and both radial axes.
            // One unit is half as tall and ~71% as wide as four units;
            // openings remain round and physical volume stays proportional.
            let heightScale=sqrt(volumeScale)
            let height=2.35*heightScale
            let raw=LabVesselProfile(name:spec.0,height:height,knots:spec.1)
            return LabVesselProfile(name:spec.0,height:height,knots:spec.1,
                radialScale:sqrt(reference/raw.usableVolume*volumeScale))
        }
    }
    static func vessels(profiles:[LabVesselProfile],capacities:[Int]?=nil,move:LabBoardMove?,time:Float,tilt:Float,cutoffTilt:Float?,cutoffElapsed:Float,returnElapsed:Float?,approach:Float=0,depthSide:Float=0) -> [LabVesselUniform] {
        let homes=homes(count:profiles.count)
        var positions=homes,rotations=[simd_float4x4](repeating:matrix_identity_float4x4,count:profiles.count)
        if let move {
            let home=homes[move.source], receiver=homes[move.destination]
            let sign:Float=approach==0 ? (receiver.x >= home.x ? 1:-1):approach
            // Separate travel in depth, including late joins and the return path.
            let side:Float=depthSide==0 ? 1:depthSide
            let direction=SIMD3<Float>(sign*0.7,0,-side*sqrt(0.51))
            let yaw=atan2(-direction.z,direction.x)
            let cy=cos(yaw),sy=sin(yaw)
            let orient=simd_float4x4(SIMD4(cy,0,-sy,0),SIMD4(0,1,0,0),SIMD4(sy,0,cy,0),SIMD4(0,0,0,1))
            func rotation(_ tilt:Float) -> simd_float4x4 { orient*labRotation(-tilt) }
            let h=profiles[move.source].height
            let travelClearance=(profiles.map(\.height).max() ?? 2.35)+0.35
            let highHome=home+SIMD3<Float>(0,travelClearance,depthSide==0 ? 0:side*1.5)
            let extraCapacity=Float(max(0,max(capacities?[move.source] ?? 4,capacities?[move.destination] ?? 4)-4))
            let standardSeparation:Float=0.22+0.27*extraCapacity
            let separation:Float=approach==0 ? standardSeparation:1.2
            let highLip=receiver-direction*separation+SIMD3<Float>(0,highHome.y+h-receiver.y,0)
            let pouringLip=receiver-direction*(approach==0 ? standardSeparation:max(0.65,standardSeparation))+SIMD3<Float>(0,profiles[move.destination].height+0.59,0)
            var position=simd_mix(home,highHome,SIMD3(repeating:labLiftProgress(time/LabBoardTiming.lift)))
            if time>=LabBoardTiming.lift { position=simd_mix(highHome,highLip-SIMD3(0,h,0),SIMD3(repeating:labSmooth((time-LabBoardTiming.lift)/LabBoardTiming.travel))) }
            // Bring the nozzle into guide range before the first liquid exits.
            // Keeping it at travel height during early tilt can launch a small
            // top layer over the receiver before the guide can engage.
            func lip(_ tilt:Float) -> SIMD3<Float> {
                simd_mix(highLip,pouringLip,SIMD3(repeating:labSmooth((tilt-(depthSide==0 ? 0.55:0.25))/(depthSide==0 ? 0.95:0.90))))
            }
            if time>=LabBoardTiming.tiltStart { position=lip(tilt)-(rotation(tilt)*SIMD4<Float>(0,h,0,0)).xyz }
            if let initial=cutoffTilt {
                let initialLip=lip(initial)
                if cutoffElapsed<LabBoardTiming.stop { position=initialLip-(rotation(tilt)*SIMD4<Float>(0,h,0,0)).xyz }
                else {
                    let stopped=max(0,initial-0.45)
                    let pivot=initialLip-(rotation(stopped)*SIMD4<Float>(0,h,0,0)).xyz
                    position=simd_mix(pivot,SIMD3(pivot.x,highHome.y,pivot.z),SIMD3(repeating:labSmooth((cutoffElapsed-LabBoardTiming.stop)/LabBoardTiming.upright)))
                }
            }
            if let back=returnElapsed,let initial=cutoffTilt {
                let pivot=lip(initial)-(rotation(max(0,initial-0.45))*SIMD4<Float>(0,h,0,0)).xyz
                let raised=SIMD3<Float>(pivot.x,highHome.y,pivot.z)
                position=simd_mix(raised,highHome,SIMD3(repeating:labSmooth(back/LabBoardTiming.returnTravel)))
                position=simd_mix(position,home,SIMD3(repeating:labSmooth((back-LabBoardTiming.returnTravel)/LabBoardTiming.lower)))
            }
            positions[move.source]=position;rotations[move.source]=rotation(tilt)
        }
        return profiles.enumerated().map { i,p in
            let world=labTranslation(positions[i])*rotations[i]
            let role:Float=move?.source == i ? (tilt>0.95 ? 1:3):(move?.destination == i ? 2:0)
            let capacity=capacities?[i] ?? 4
            func mark(_ unit:Int)->Float {
                unit<=capacity ? p.height(for:p.usableVolume*Float(unit)/Float(capacity)):-100
            }
            return LabVesselUniform(world:world,inverseWorld:world.inverse,previousWorld:world,
                dimensions:SIMD4(p.height,Float(i),0.035,role),
                marks:SIMD4(mark(1),mark(2),mark(3),mark(4)),
                shape:SIMD4(p.depthScale,mark(5),mark(6),Float(capacity)))
        }
    }
    static func camera(aspect:Float,azimuth:Float,vesselCount:Int = 4) -> (simd_float4x4,simd_float4x4,SIMD3<Float>) {
        // Fixed framing includes outward edge pours in either depth lane.
        // Resting and active boards share a camera, avoiding a zoom at pickup.
        // Match the normalized scale used by Classic and 2D. Their layout is
        // width-limited on the very wide iPad playfield, while the old fixed
        // camera distance stayed sized for a much narrower viewport and made
        // 3D vials look conspicuously smaller. A modest perspective margin
        // accounts for depth and avoids framing resting glass at the edge.
        let verticalScale:Float=1/tan(aspect<1.4 ? 0.235*1.4/max(aspect,0.55):0.235)
        let planarScale=min(aspect/(Float(vesselCount)*2.2+4.4),1/6.4)
        let distance=verticalScale/max(0.001,2*planarScale)*1.07
        let target=SIMD3<Float>(0,3.1,0)
        let eye=SIMD3<Float>(sin(azimuth)*distance,target.y+2.9,cos(azimuth)*distance)
        let forward=simd_normalize(eye-target),right=simd_normalize(simd_cross(SIMD3<Float>(0,1,0),forward)),up=simd_cross(forward,right)
        let view=simd_float4x4(SIMD4(right.x,up.x,forward.x,0),SIMD4(right.y,up.y,forward.y,0),SIMD4(right.z,up.z,forward.z,0),SIMD4(-simd_dot(right,eye),-simd_dot(up,eye),-simd_dot(forward,eye),1))
        // Lens-shift the projection so the common vial floor remains at the
        // same 82% screen baseline as the planar modes at every aspect ratio.
        let floor=view*SIMD4<Float>(0,0.18,0,1)
        let floorNDC=verticalScale*floor.y / -floor.z
        let verticalShift:Float = -0.64-floorNDC
        let near:Float=0.1,far:Float=50
        let p=simd_float4x4(SIMD4(verticalScale/aspect,0,0,0),SIMD4(0,verticalScale,0,0),SIMD4(0,-verticalShift,far/(near-far),-1),SIMD4(0,0,near*far/(near-far),0))
        return (p*view,view,eye)
    }
}

/// A presentation-only transaction. The game commits once, after the animation;
/// elapsed time advances only while the board is active and unpaused.
nonisolated struct LabMixTransition:Sendable {
    let before:LabBoardState
    let after:LabBoardState
    let apparatus:LabApparatus
    var time:Float=0
    var reduceMotion=false
    static let duration:Float=2.8
    var output:Int { apparatus.output! }
    var parcels:Set<Int> { Set(apparatus.inputs.flatMap {before.stacks[$0]}) }
    var vessels:Set<Int> { Set(apparatus.inputs+[output]) }
    var gathered:Float { labSmooth(time/1.15) }
    var blend:Float { labSmooth((time-0.85)/1.65) }
    var agitation:Float { reduceMotion ? 0:labSmooth(time/0.7)*(1-labSmooth((time-1.8)/1.0)) }
    var finished:Bool { time>=Self.duration }
    func position(from:SIMD3<Float>,to:SIMD3<Float>,origin:SIMD3<Float>,profile:LabVesselProfile,phase:Float)->(point:SIMD3<Float>,arrived:Bool,started:Bool) {
        let f=labSmooth((time-phase*0.35)/0.8)
        var local=to-origin
        let top=profile.height(for:profile.usableVolume*2/Float(after.capacity(output)))-0.04
        let middle=(top+0.04)*0.5,halfHeight=max(0.02,(top-0.04)*0.5)
        let initialRadius=max(0.02,profile.radius(at:local.y)-0.05)
        let nx=local.x/initialRadius,ny=(local.y-middle)/halfHeight
        // Turn the whole cross-section, not just horizontal rings: colors fold
        // through one another vertically before they become the same material.
        let angle=time*5+ny*0.65
        let rotatedX=nx*cos(angle)-ny*sin(angle)
        local.y=min(top,max(0.04,middle+(nx*sin(angle)+ny*cos(angle))*halfHeight))
        local.x=rotatedX*max(0.01,profile.radius(at:local.y)-0.05)
        let radius=max(0.01,profile.radius(at:local.y)-0.05),length=simd_length(SIMD2(local.x,local.z))
        if length>radius { local.x*=radius/length;local.z*=radius/length }
        local=simd_mix(to-origin,local,SIMD3(repeating:agitation))
        let target=origin+local
        // Pumped arcs connect the two input ports to the output. Each particle
        // retains its identity and original color until it enters the mixer.
        let clearance=max(from.y,profile.height)+0.65
        let a=SIMD3(from.x,clearance,from.z),b=SIMD3(origin.x,clearance,origin.z)
        let point=pow(1-f,3)*from+3*pow(1-f,2)*f*a+3*(1-f)*f*f*b+f*f*f*target
        return (point,f>=1,f>0)
    }
}
