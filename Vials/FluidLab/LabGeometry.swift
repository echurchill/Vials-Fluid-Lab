import Foundation
import simd

/// Dimensions are scene units; material constants are tuned for this visual experiment.
/// All volume calculations use the interior profile, never the outside silhouette.
nonisolated struct LabVesselProfile:Sendable {
    static let sampleCount = 128
    let name: String
    let height: Float
    let radii: [Float]
    let cumulativeVolumes: [Float]
    let usableVolume: Float

    init(name: String, height: Float, knots: [(Float, Float)], radialScale: Float = 1) {
        self.name = name
        self.height = height
        radii = (0..<Self.sampleCount).map { index in
            let y = Float(index) / Float(Self.sampleCount - 1)
            let upper = knots.firstIndex { $0.0 >= y } ?? knots.count - 1
            guard upper > 0 else { return knots[0].1 * radialScale }
            let a = knots[upper - 1], b = knots[upper]
            let t = (y - a.0) / max(0.0001, b.0 - a.0)
            return (a.1 + (b.1 - a.1) * t) * radialScale
        }
        var volumes: [Float] = [0]
        let dy = height / Float(Self.sampleCount - 1)
        for i in 1..<Self.sampleCount {
            let a = radii[i - 1], b = radii[i]
            // Exact integral of pi*r(y)^2 for a linear radius segment.
            volumes.append(volumes[i - 1] + .pi * dy * (a*a + a*b + b*b) / 3)
        }
        cumulativeVolumes = volumes
        usableVolume = Self.volume(at: height - 0.20, height: height, radii: radii, cumulative: volumes)
    }

    func radius(at y: Float) -> Float {
        let f = min(max(y / height, 0), 1) * Float(Self.sampleCount - 1)
        let i = min(Int(f), Self.sampleCount - 2)
        return radii[i] + (radii[i + 1] - radii[i]) * (f - Float(i))
    }

    func volume(at y: Float) -> Float {
        Self.volume(at: y, height: height, radii: radii, cumulative: cumulativeVolumes)
    }

    private static func volume(at y: Float, height: Float, radii: [Float], cumulative: [Float]) -> Float {
        let y = min(max(y, 0), height)
        let f = y / height * Float(Self.sampleCount - 1)
        let i = min(Int(f), Self.sampleCount - 2)
        let t = f - Float(i)
        let a = radii[i], b = a + (radii[i + 1] - a) * t
        let dy = height / Float(Self.sampleCount - 1) * t
        return cumulative[i] + .pi * dy * (a*a + a*b + b*b) / 3
    }

    func height(for volume: Float) -> Float {
        var lo: Float = 0, hi = height
        for _ in 0..<28 {
            let mid = (lo + hi) / 2
            if self.volume(at: mid) < volume { lo = mid } else { hi = mid }
        }
        return (lo + hi) / 2
    }

    static func pair() -> [LabVesselProfile] {
        let tube = LabVesselProfile(name: "Rounded vial", height: 2.35,
            knots: [(0, 0.24), (0.025, 0.35), (0.085, 0.47), (1, 0.47)])
        let bulbKnots: [(Float, Float)] = [(0, 0.28), (0.04, 0.47), (0.16, 0.70),
            (0.34, 0.74), (0.49, 0.61), (0.66, 0.30), (0.74, 0.32), (0.87, 0.32), (0.94, 0.40), (1, 0.54)]
        let bulb = LabVesselProfile(name: "Bulb flask", height: 2.35, knots: bulbKnots)
        return [tube, LabVesselProfile(name: "Bulb flask", height: 2.35,
            knots: bulbKnots, radialScale: sqrt(tube.usableVolume / bulb.usableVolume))]
    }
}

struct LabParticle {
    var position: SIMD4<Float> // w: current vessel, -1 when in flight/on the tray
    var predicted: SIMD4<Float>
    var velocity: SIMD4<Float> // w: passive dye identity (0 turquoise, 1 amber)
    var visual: SIMD4<Float> = .zero // x: final-correction fade-in timestamp; zero for untouched particles
}

struct LabVertex {
    var position: SIMD4<Float>
    var normal: SIMD4<Float>
}

struct LabVesselUniform {
    var world: simd_float4x4
    var inverseWorld: simd_float4x4
    var previousWorld: simd_float4x4
    var dimensions: SIMD4<Float> // height, profile index, wall thickness, unused
    var marks: SIMD4<Float>
}

struct LabUniforms {
    var viewProjection: simd_float4x4
    var inverseViewProjection: simd_float4x4
    var view: simd_float4x4
    var camera: SIMD4<Float>
    var viewport: SIMD4<Float> // width, height, particle radius, time
    var physics: SIMD4<Float> // dt, smoothing radius, particle volume, viscosity
    var options: SIMD4<UInt32> // particle count, point mode, unused, unused
}

struct LabFrameStats {
    var source = 0
    var destination = 0
    var airborne = 0
    var spilled = 0
    var nonFinite = 0
    var maximumSpeed: Float = 0
    var gpuMilliseconds: Double = 0
}

func labTranslation(_ v: SIMD3<Float>) -> simd_float4x4 {
    var m = matrix_identity_float4x4
    m.columns.3 = SIMD4(v, 1)
    return m
}

func labRotation(_ angle: Float) -> simd_float4x4 {
    let c = cos(angle), s = sin(angle)
    return simd_float4x4(SIMD4(c,s,0,0), SIMD4(-s,c,0,0), SIMD4(0,0,1,0), SIMD4(0,0,0,1))
}

nonisolated func labSmooth(_ t: Float) -> Float {
    let t = min(max(t, 0), 1)
    return t*t*t*(t*(t*6-15)+10)
}

/// A pose driven by the metering controller. Return begins only after flow cutoff.
func labVessels(time: Float?, profiles: [LabVesselProfile], horizontalOffset: Float = 0,
                tilt: Float = 0, returnTime: Float? = nil, cutoffTilt: Float? = nil, cutoffElapsed: Float = 0) -> [LabVesselUniform] {
    let home = SIMD3<Float>(-1.25, 0.18, 0)
    let receiver = SIMD3<Float>(1.10, 0.18, 0)
    let highHome = home + SIMD3<Float>(0, 2.45, 0)
    let highLip = SIMD3<Float>(0.65 + horizontalOffset, highHome.y + profiles[0].height, 0)
    let pouringLip = SIMD3<Float>(0.65 + horizontalOffset, 3.10, 0)
    var position = home
    let angle = -tilt
    if let time {
        position = simd_mix(home, highHome, SIMD3(repeating:labSmooth(time / 1.4)))
        if time >= 1.4 {
            position = simd_mix(highHome,highLip-SIMD3(0,profiles[0].height,0),SIMD3(repeating:labSmooth((time-1.4)/1.2)))
        }
        if time >= 2.6 {
            let descend = labSmooth((tilt-0.32)/0.85)
            let lip = simd_mix(highLip,pouringLip,SIMD3(repeating:descend))
            position = lip - (labRotation(angle)*SIMD4<Float>(0,profiles[0].height,0,0)).xyz
        }
        if let initialTilt=cutoffTilt {
            let initialLip=simd_mix(highLip,pouringLip,SIMD3(repeating:labSmooth((initialTilt-0.32)/0.85)))
            if cutoffElapsed < 0.8 {
                // Keep the actual mouth over the receiver until the tail drains.
                position=initialLip-(labRotation(angle)*SIMD4<Float>(0,profiles[0].height,0,0)).xyz
            } else {
                let stoppedTilt=max(0,initialTilt-0.45)
                let pivot=initialLip-(labRotation(-stoppedTilt)*SIMD4<Float>(0,profiles[0].height,0,0)).xyz
                position=simd_mix(pivot,highHome,SIMD3(repeating:labSmooth((cutoffElapsed-0.8)/1.6)))
            }
        }
        if let back=returnTime {
            position = highHome
            position = simd_mix(position,home,SIMD3(repeating:labSmooth(back/1.4)))
        }
    }
    return profiles.enumerated().map { i,p in
        let world=labTranslation(i == 0 ? position:receiver)*labRotation(i == 0 ? angle:0)
        return LabVesselUniform(world:world,inverseWorld:world.inverse,previousWorld:world,
            dimensions:SIMD4(p.height,Float(i),0.035,0),
            marks:SIMD4(p.height(for:p.usableVolume*0.25),p.height(for:p.usableVolume*0.5),
                        p.height(for:p.usableVolume*0.75),p.height(for:p.usableVolume)))
    }
}

/// Integer puzzle quantities stay independent of GPU floating-point outcomes.
/// A transfer is only committed after the visible pour passes its acceptance gate.
struct LabTransferLedger {
    private(set) var sourceUnits = 3
    private(set) var destinationUnits = 0
    private(set) var committed = false
    mutating func commitOneUnit() {
        guard !committed, sourceUnits > 0, destinationUnits < 4 else { return }
        sourceUnits -= 1; destinationUnits += 1; committed = true
    }
}

func labCamera(aspect: Float, azimuth: Float = 0.35) -> (simd_float4x4, simd_float4x4, SIMD3<Float>) {
    let eye = SIMD3<Float>(sin(azimuth)*10, 3.65, cos(azimuth)*10)
    let target = SIMD3<Float>(0, 2.15, 0)
    let forward = simd_normalize(eye - target)
    let right = simd_normalize(simd_cross(SIMD3<Float>(0, 1, 0), forward))
    let up = simd_cross(forward, right)
    let view = simd_float4x4(SIMD4(right.x,up.x,forward.x,0), SIMD4(right.y,up.y,forward.y,0),
        SIMD4(right.z,up.z,forward.z,0), SIMD4(-simd_dot(right,eye),-simd_dot(up,eye),-simd_dot(forward,eye),1))
    // Expand the vertical field for a narrow portrait viewport, preserving board width.
    let y: Float = 1 / tan((aspect < 1 ? 0.32 / max(aspect,0.55) : 0.32))
    let near: Float = 0.1, far: Float = 40
    let projection = simd_float4x4(SIMD4(y/aspect,0,0,0), SIMD4(0,y,0,0),
        SIMD4(0,0,far/(near-far),-1), SIMD4(0,0,near*far/(near-far),0))
    return (projection * view, view, eye)
}

func labGlassMesh(_ profile: LabVesselProfile, rings:Int = 96, segments:Int = 96) -> [LabVertex] {
    var vertices: [LabVertex] = []
    func vertex(_ ring: Int, _ segment: Int, inner: Bool) -> LabVertex {
        let y = Float(ring) / Float(rings) * profile.height
        let a = Float(segment) / Float(segments) * 2 * Float.pi
        let r = profile.radius(at: y) + (inner ? 0 : 0.035)
        let slope = (profile.radius(at: min(y+0.005,profile.height)) - profile.radius(at: max(y-0.005,0))) / 0.01
        let n = simd_normalize(SIMD3<Float>(cos(a), -slope, sin(a))) * (inner ? -1 : 1)
        return LabVertex(position: SIMD4(r*cos(a), y, r*sin(a), 1), normal: SIMD4(n,0))
    }
    for inner in [false, true] {
        for ring in 0..<rings {
            for s in 0..<segments {
                let a = vertex(ring,s,inner:inner), b = vertex(ring+1,s,inner:inner)
                let c = vertex(ring+1,s+1,inner:inner), d = vertex(ring,s+1,inner:inner)
                vertices += inner ? [a,c,b,a,d,c] : [a,b,c,a,c,d]
            }
        }
    }
    // Lip and solid foot, separate from the cavity's open top.
    for s in 0..<segments {
        for ring in [0,rings] {
            var a = vertex(ring,s,inner:false), b = vertex(ring,s+1,inner:false)
            var c = vertex(ring,s+1,inner:true), d = vertex(ring,s,inner:true)
            let n = SIMD4<Float>(0,ring == 0 ? -1 : 1,0,0)
            a.normal=n; b.normal=n; c.normal=n; d.normal=n
            vertices += [a,b,c,a,c,d]
        }
    }
    // Solid glass base: a cavity floor and an underside, with a short outer skirt.
    let baseRadius=profile.radius(at:0)
    for s in 0..<segments {
        let a=Float(s)/Float(segments)*2*Float.pi
        let b=Float(s+1)/Float(segments)*2*Float.pi
        for underside in [false,true] {
            let y:Float=underside ? -0.06:0
            let r=baseRadius+(underside ? 0.035:0)
            let normal=SIMD4<Float>(0,underside ? -1:1,0,0)
            let center=LabVertex(position:SIMD4(0,y,0,1),normal:normal)
            let va=LabVertex(position:SIMD4(r*cos(a),y,r*sin(a),1),normal:normal)
            let vb=LabVertex(position:SIMD4(r*cos(b),y,r*sin(b),1),normal:normal)
            vertices += [center,va,vb]
        }
        let r=baseRadius+0.035
        let na=SIMD4<Float>(cos(a),0,sin(a),0), nb=SIMD4<Float>(cos(b),0,sin(b),0)
        let va=LabVertex(position:SIMD4(r*cos(a),0,r*sin(a),1),normal:na)
        let vb=LabVertex(position:SIMD4(r*cos(b),0,r*sin(b),1),normal:nb)
        let vc=LabVertex(position:SIMD4(r*cos(b),-0.06,r*sin(b),1),normal:nb)
        let vd=LabVertex(position:SIMD4(r*cos(a),-0.06,r*sin(a),1),normal:na)
        vertices += [va,vb,vc,va,vc,vd]
    }
    return vertices
}

extension SIMD4 where Scalar == Float {
    var xyz: SIMD3<Float> { SIMD3(x,y,z) }
}
