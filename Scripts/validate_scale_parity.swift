import Foundation
import simd

@main struct ScaleParityValidation {
    static func projected(_ point:SIMD3<Float>,matrix:simd_float4x4)->SIMD2<Float> {
        let clip=matrix*SIMD4(point,1)
        return SIMD2(clip.x/clip.w,clip.y/clip.w)
    }
    static func main() {
        let aspects:[Float]=[0.6,0.75,1,1.667,2.75,3.3]
        let counts=[4,6,8,10]
        var worstScaleError:Float=0,worstBaselineError:Float=0
        for count in counts {
            let profiles=LabBoardLayout.profiles(count:count)
            let center=max(0,(count-1)/2),home=LabBoardLayout.homes(count:count)[center]
            for aspect in aspects {
                let camera=LabBoardLayout.camera(aspect:aspect,azimuth:0.12,vesselCount:count).0
                let bottom=projected(home,matrix:camera),top=projected(home+SIMD3(0,profiles[center].height,0),matrix:camera)
                let planar=min(aspect/(Float(count)*2.2+4.4),1/6.4)
                let ratio=(top.y-bottom.y)/(2*profiles[center].height*planar)
                let baseline=0.5-bottom.y/2
                worstScaleError=max(worstScaleError,abs(1-ratio));worstBaselineError=max(worstBaselineError,abs(0.82-baseline))
                guard ratio>0.82 && ratio<1.02 else {
                    print("FAIL: 3D/planar scale mismatch: count=\(count) aspect=\(aspect) ratio=\(ratio)");exit(1)
                }
                guard abs(0.82-baseline)<0.025 else {
                    print("FAIL: 3D/planar baseline mismatch: count=\(count) aspect=\(aspect) baseline=\(baseline)");exit(1)
                }
            }
        }
        print("PASS: resting 3D scale tracks Classic/2D across 4–10 vials and portrait/landscape; max scale error \(worstScaleError), baseline error \(worstBaselineError)")
    }
}
