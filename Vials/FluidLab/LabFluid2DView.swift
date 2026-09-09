import SwiftUI

/// A planar surface reconstructed from particles; the glass is an illustrated outline.
struct LabFluid2DView:View {
    let engine:LabFluid2D
    var points=false
    var frame:Int=0 // Explicitly invalidate Canvas as the reference-type solver advances.
    var body:some View {
        Canvas { context,size in
            let layout=LabClassicLayout(size:size,vesselCount:engine.profiles.count)
            let scale=layout.scale,origin=CGPoint(x:size.width/2,y:layout.base(0).y)
            func screen(_ p:SIMD2<Float>)->CGPoint { CGPoint(x:origin.x+CGFloat(p.x)*scale,y:origin.y-CGFloat(p.y)*scale) }
            func cavity(_ index:Int)->Path {
                let profile=engine.profiles[index],pose=engine.pose(index)
                return Path { path in
                    for side:Float in [1,-1] {
                        let range=side>0 ? Array(0...128):Array((0...128).reversed())
                        for k in range {
                            let y=Float(k)/128*profile.height
                            let point=screen(pose.world(SIMD2(side*profile.radius(y),y)))
                            if k==0 && side>0 { path.move(to:point) } else { path.addLine(to:point) }
                        }
                    }
                    path.closeSubpath()
                }
            }
            var baseline=Path();baseline.move(to:CGPoint(x:size.width*0.06,y:origin.y+7));baseline.addLine(to:CGPoint(x:size.width*0.94,y:origin.y+7))
            context.stroke(baseline,with:.color(.white.opacity(0.08)),lineWidth:1)
            for index in engine.profiles.indices { context.fill(cavity(index),with:.color(.white.opacity(0.028))) }
            for owner in -1..<engine.profiles.count {
                let owned=engine.particles.filter { $0.owner==owner }
                guard !owned.isEmpty else { continue }
                var liquid=context
                if owner>=0 { liquid.clip(to:cavity(owner)) }
                for color in Set(owned.map(\.color)).sorted() {
                    let ink=FluidBoardSession.color(color)
                    let group=owned.filter { $0.color==color }
                    if points {
                        for p in group {
                            let point=screen(p.position),r=scale*CGFloat(engine.radius)*0.55
                            liquid.fill(Path(ellipseIn:CGRect(x:point.x-r,y:point.y-r,width:r*2,height:r*2)),with:.color(ink))
                        }
                    } else {
                        liquid.drawLayer { surface in
                            surface.addFilter(.alphaThreshold(min:0.40,color:ink))
                            surface.addFilter(.blur(radius:max(0.5,scale*0.045)))
                            var blobs=Path()
                            let r=scale*CGFloat(engine.separation)*0.90
                            for p in group {
                                let point=screen(p.position)
                                blobs.addEllipse(in:CGRect(x:point.x-r,y:point.y-r,width:r*2,height:r*2))
                            }
                            surface.fill(blobs,with:.color(.white))
                        }
                    }
                }
            }
            for index in engine.profiles.indices {
                let profile=engine.profiles[index],pose=engine.pose(index),shape=cavity(index)
                let bottom=screen(pose.base),top=screen(pose.world(SIMD2(0,profile.height)))
                context.stroke(shape,with:.linearGradient(Gradient(colors:[.white.opacity(0.58),Color.cyan.opacity(0.15),.white.opacity(0.30)]),startPoint:top,endPoint:bottom),style:StrokeStyle(lineWidth:1.6,lineJoin:.round))
                // Open mouth: two short lip highlights, no cap across the stream.
                for side:Float in [-1,1] {
                    let lip=screen(pose.world(SIMD2(side*profile.radius(profile.height),profile.height)))
                    context.fill(Path(ellipseIn:CGRect(x:lip.x-2,y:lip.y-2,width:4,height:4)),with:.color(.white.opacity(0.65)))
                    var glint=Path()
                    for k in 15...110 {
                        let y=Float(k)/128*profile.height
                        let p=screen(pose.world(SIMD2(side*(profile.radius(y)-0.055),y)))
                        if k==15 { glint.move(to:p) } else { glint.addLine(to:p) }
                    }
                    context.stroke(glint,with:.color(.white.opacity(side<0 ? 0.12:0.05)),lineWidth:1.8)
                }
                for unit in 1...4 {
                    let y=profile.level(Float(unit)),r=profile.radius(y)
                    var mark=Path();mark.move(to:screen(pose.world(SIMD2(r*0.60,y))));mark.addLine(to:screen(pose.world(SIMD2(r*0.9,y))))
                    context.stroke(mark,with:.color(.white.opacity(0.28)),lineWidth:1)
                }
            }
        }.accessibilityHidden(true)
    }
}
