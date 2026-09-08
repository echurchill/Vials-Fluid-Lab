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
    static func profiles(count:Int = 4) -> [LabVesselProfile] {
        let base=LabVesselProfile.pair()
        func shape(_ name:String,_ knots:[(Float,Float)]) -> LabVesselProfile {
            let raw=LabVesselProfile(name:name,height:2.35,knots:knots)
            return LabVesselProfile(name:name,height:2.35,knots:knots,radialScale:sqrt(base[0].usableVolume/raw.usableVolume))
        }
        let shapes=[base[0],base[1],shape("Tapered flask",[(0,0.58),(0.07,0.64),(0.52,0.50),(0.80,0.31),(0.91,0.34),(1,0.54)]),
                shape("Pear flask",[(0,0.25),(0.06,0.48),(0.27,0.69),(0.49,0.59),(0.73,0.32),(0.91,0.32),(1,0.54)])]
        return (0..<count).map { shapes[$0 % shapes.count] }
    }
    static func vessels(profiles:[LabVesselProfile],move:LabBoardMove?,time:Float,tilt:Float,cutoffTilt:Float?,cutoffElapsed:Float,returnElapsed:Float?) -> [LabVesselUniform] {
        let homes=homes(count:profiles.count)
        var positions=homes,rotations=[simd_float4x4](repeating:matrix_identity_float4x4,count:profiles.count)
        if let move {
            let home=homes[move.source], receiver=homes[move.destination]
            let sign:Float=receiver.x >= home.x ? 1:-1
            let direction=SIMD3<Float>(sign*0.7,0,-sqrt(0.51))
            let yaw=atan2(-direction.z,direction.x)
            let cy=cos(yaw),sy=sin(yaw)
            let orient=simd_float4x4(SIMD4(cy,0,-sy,0),SIMD4(0,1,0,0),SIMD4(sy,0,cy,0),SIMD4(0,0,0,1))
            func rotation(_ tilt:Float) -> simd_float4x4 { orient*labRotation(-tilt) }
            let h=profiles[move.source].height
            let highHome=home+SIMD3<Float>(0,2.65,0)
            let highLip=receiver-direction*0.22+SIMD3<Float>(0,highHome.y+h-receiver.y,0)
            let pouringLip=SIMD3<Float>(highLip.x,receiver.y+profiles[move.destination].height+0.59,highLip.z)
            var position=simd_mix(home,highHome,SIMD3(repeating:labSmooth(time/LabBoardTiming.lift)))
            if time>=LabBoardTiming.lift { position=simd_mix(highHome,highLip-SIMD3(0,h,0),SIMD3(repeating:labSmooth((time-LabBoardTiming.lift)/LabBoardTiming.travel))) }
            func lip(_ tilt:Float) -> SIMD3<Float> {
                simd_mix(highLip,pouringLip,SIMD3(repeating:labSmooth((tilt-0.55)/0.95)))
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
            return LabVesselUniform(world:world,inverseWorld:world.inverse,previousWorld:world,
                dimensions:SIMD4(p.height,Float(i),0.035,role),marks:SIMD4(p.height(for:p.usableVolume/4),p.height(for:p.usableVolume/2),p.height(for:p.usableVolume*0.75),p.height(for:p.usableVolume)))
        }
    }
    static func camera(aspect:Float,azimuth:Float,vesselCount:Int = 4) -> (simd_float4x4,simd_float4x4,SIMD3<Float>) {
        let distance:Float=vesselCount>4 ? 20:14
        let eye=SIMD3<Float>(sin(azimuth)*distance,5.4,cos(azimuth)*distance),target=SIMD3<Float>(0,2.5,0)
        let forward=simd_normalize(eye-target),right=simd_normalize(simd_cross(SIMD3<Float>(0,1,0),forward)),up=simd_cross(forward,right)
        let view=simd_float4x4(SIMD4(right.x,up.x,forward.x,0),SIMD4(right.y,up.y,forward.y,0),SIMD4(right.z,up.z,forward.z,0),SIMD4(-simd_dot(right,eye),-simd_dot(up,eye),-simd_dot(forward,eye),1))
        let y:Float=1/tan(aspect<1.4 ? 0.235*1.4/max(aspect,0.55):0.235),near:Float=0.1,far:Float=50
        let p=simd_float4x4(SIMD4(y/aspect,0,0,0),SIMD4(0,y,0,0),SIMD4(0,0,far/(near-far),-1),SIMD4(0,0,near*far/(near-far),0))
        return (p*view,view,eye)
    }
}
