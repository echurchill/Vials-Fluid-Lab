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
                        var blobs=Path(),cores=Path()
                        for (index,p) in group.enumerated() {
                            let point=screen(p.position)
                            let speed=sqrt(p.velocity.x*p.velocity.x+p.velocity.y*p.velocity.y)
                            let flying = !p.inBulk
                            let r=scale*CGFloat(engine.separation)*(flying ? 0.62:0.90)
                            let stretch=flying ? CGFloat(min(1.75,1+speed*0.24)):1
                            let angle=flying ? atan2(CGFloat(-p.velocity.y),CGFloat(p.velocity.x)):0
                            let oval=Path(ellipseIn:CGRect(x:-r*stretch,y:-r/stretch,width:2*r*stretch,height:2*r/stretch))
                            blobs.addPath(oval,transform:CGAffineTransform(rotationAngle:angle).concatenating(CGAffineTransform(translationX:point.x,y:point.y)))
                            if color==0 && (flying || index%5==0) {
                                let core=scale*CGFloat(engine.radius)*(flying ? 0.28:0.22)
                                cores.addEllipse(in:CGRect(x:point.x-core,y:point.y-core,width:core*2,height:core*2))
                            }
                        }
                        func mask(_ ctx:inout GraphicsContext,_ tint:Color) {
                            ctx.addFilter(.alphaThreshold(min:0.40,color:tint))
                            ctx.addFilter(.blur(radius:max(0.5,scale*0.033)))
                            ctx.fill(blobs,with:.color(.white))
                        }
                        if color==0 {
                            liquid.drawLayer { glow in
                                glow.addFilter(.blur(radius:scale*0.06))
                                glow.fill(blobs,with:.color(Color.cyan.opacity(0.16)))
                            }
                        }
                        var body=liquid
                        body.opacity=color==0 ? 0.50:(color==2 ? 0.92:1)
                        body.drawLayer { surface in mask(&surface,ink) }
                        var detail=liquid
                        detail.clipToLayer { clip in mask(&clip,.white) }
                        if color==0 {
                            detail.drawLayer { glow in
                                glow.addFilter(.blur(radius:1.3))
                                glow.stroke(cores,with:.color(Color.cyan.opacity(0.48)),lineWidth:1.8)
                            }
                            detail.fill(cores,with:.color(Color(red:0.40,green:0.90,blue:1).opacity(0.85)))
                        } else if owner>=0 {
                            let pose=engine.pose(owner),profile=engine.profiles[owner]
                            let local=group.filter(\.inBulk).map { pose.local($0.position) }
                            if let low=local.map(\.y).min(),let high=local.map(\.y).max(),high-low>0.05 {
                                let t=engine.materialTimes[owner]
                                let bottom=low-engine.radius,top=high+engine.radius,height=top-bottom
                                if color==1 {
                                    // Decorative bubbles follow the vessel and are masked to orange liquid.
                                    // They are not simulated air volume and cannot change the fill level.
                                    for n in 0..<10 {
                                        let seed=Float(n)
                                        let phase=(seed*0.173+t*0.20).truncatingRemainder(dividingBy:1)
                                        let y=bottom+phase*height
                                        let x=sin(seed*2.41+t*0.65)*profile.radius(y)*0.70
                                        let point=screen(pose.world(SIMD2(x,y)))
                                        let pop=max(0,(phase-0.91)/0.09)
                                        let r=scale*CGFloat(0.018+Float(n%3)*0.008)*(1+CGFloat(pop)*0.9)
                                        let bubble=Path(ellipseIn:CGRect(x:point.x-r,y:point.y-r,width:r*2,height:r*2))
                                        detail.fill(bubble,with:.color(Color(red:1,green:0.85,blue:0.40).opacity(0.09*Double(1-pop))))
                                        detail.stroke(bubble,with:.color(Color(red:1,green:0.88,blue:0.50).opacity(0.56*Double(1-pop))),lineWidth:0.8)
                                    }
                                } else {
                                    // A few broad, quiet ribbons provide a silky material cue.
                                    for n in 0..<3 {
                                        var ribbon=Path()
                                        for k in 0...28 {
                                            let f=Float(k)/28,y=bottom+f*height
                                            let wave=sin(f*5.2+t*0.6+Float(n)*2.1)
                                            let x=(Float(n)-1)*profile.radius(y)*0.40+wave*profile.radius(y)*0.20
                                            let point=screen(pose.world(SIMD2(x,y)))
                                            if k==0 { ribbon.move(to:point) } else { ribbon.addLine(to:point) }
                                        }
                                        detail.stroke(ribbon,with:.color(Color(red:0.67,green:1,blue:0.79).opacity(0.19)),style:StrokeStyle(lineWidth:max(1,scale*0.035),lineCap:.round))
                                    }
                                }
                            }
                        }

                    }
                }
            }
            for index in engine.profiles.indices {
                let profile=engine.profiles[index],pose=engine.pose(index)
                let bottom=screen(pose.base),top=screen(pose.world(SIMD2(0,profile.height)))
                var outline=Path()
                for side:Float in [1,-1] {
                    let steps=side>0 ? Array((0...128).reversed()):Array(0...128)
                    for k in steps {
                        let y=Float(k)/128*profile.height,point=screen(pose.world(SIMD2(side*profile.radius(y),y)))
                        if side>0 && k==128 { outline.move(to:point) } else { outline.addLine(to:point) }
                    }
                }
                context.stroke(outline,with:.linearGradient(Gradient(colors:[.white.opacity(0.58),Color.cyan.opacity(0.15),.white.opacity(0.30)]),startPoint:top,endPoint:bottom),style:StrokeStyle(lineWidth:1.6,lineJoin:.round))
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
