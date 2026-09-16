import Foundation
import simd
@main struct GeometryProbe {
 static func main() throws {
  var rows:[[String:Any]]=[]
  for count in [4,6] {
  let profiles=LabBoardLayout.profiles(count:count),last=count-1
  let cases=[("crossing",0,last,last-1,1),("shared-left",last-1,0,last,0),("shared-right",0,last,1,last),("neighbors",0,1,last,last-1)]
  func pose(_ source:Int,_ destination:Int,_ sign:Float,_ side:Float,_ time:Float)->LabVesselUniform {
   let move=LabBoardMove(source:source,destination:destination,parcels:[source],color:0)
   let cutoff:Float=3.7,elapsed=max(0,time-cutoff),initial:Float=2.05
   let tilt:Float=time<cutoff ? min(initial,max(0,time-0.95)*1.1):(elapsed<0.2 ? initial-0.45*labSmooth(elapsed/0.2):1.6*(1-labSmooth((elapsed-0.2)/0.5)))
   return LabBoardLayout.vessels(profiles:profiles,move:move,time:max(0,time),tilt:tilt,cutoffTilt:time>=cutoff ? initial:nil,cutoffElapsed:elapsed,returnElapsed:elapsed>=0.7 ? elapsed-0.7:nil,approach:sign,depthSide:side)[source]
  }
  func penetration(_ a:LabVesselUniform,_ b:LabVesselUniform,_ ap:LabVesselProfile,_ bp:LabVesselProfile)->Float {
   var deepest:Float=0
   for level in 0...24 {
    let y=ap.height*Float(level)/24,r=ap.radius(at:y)+0.035
    for ring in 0..<16 {
     let angle=Float(ring)*2*Float.pi/16
     let q=(b.inverseWorld*a.world*SIMD4(r*cos(angle),y,r*sin(angle),1)).xyz
     if q.y>0 && q.y<bp.height {deepest=max(deepest,min(min(q.y,bp.height-q.y),bp.radius(at:q.y)+0.035-length(SIMD2(q.x,q.z))))}
    }
   }
   return deepest
  }
  for lane:Float in [-1,1] {for (name,a,ad,b,bd) in cases {for delay:Float in [0,0.5,1.5,3.5] {
   let sa:Float=ad>a ? 1:-1,sb:Float=ad==bd ? -sa:(bd>b ? 1:-1)
   var worst:Float=0,worstTime:Float=0,extent:Float=0
   for step in 0...180 {
    let t=Float(step)*0.05
    let pa=pose(a,ad,sa,lane,t),pb=pose(b,bd,sb,-lane,t-delay)
    for aspect:Float in [0.6,1.667] {for orbit:Float in [-0.3,0.12,0.4] {
     let camera=LabBoardLayout.camera(aspect:aspect,azimuth:orbit,vesselCount:count).0
     for (v,p) in [(pa,profiles[a]),(pb,profiles[b])] {
      for level in 0...12 {for ring in 0..<12 {
       let y=p.height*Float(level)/12,r=p.radius(at:y)+0.035,angle=Float(ring)*2*Float.pi/12
       let clip=camera*v.world*SIMD4(r*cos(angle),y,r*sin(angle),1)
       extent=max(extent,max(abs(clip.x/clip.w),abs(clip.y/clip.w)))
      }}
     }
    }}
    let depth=max(penetration(pa,pb,profiles[a],profiles[b]),penetration(pb,pa,profiles[b],profiles[a]))
    if depth>worst {worst=depth;worstTime=t}
   }
   rows.append(["vialCount":count,"firstLane":lane,"case":name,"delay":delay,"maximumPenetration":worst,"atTime":worstTime,"maximumScreenExtent":extent])
  }}}
  }
  let data=try JSONSerialization.data(withJSONObject:rows,options:[.prettyPrinted,.sortedKeys]);try data.write(to:URL(fileURLWithPath:CommandLine.arguments[1]));print(String(data:data,encoding:.utf8)!)
  precondition(rows.allSatisfy {($0["maximumPenetration"] as! Float)<0.025 && ($0["maximumScreenExtent"] as! Float)<0.99},"Path intersection or camera clipping")
 }
}
