import SwiftUI

/// A planar surface reconstructed from particles; layered glass follows the same interior profile.
struct LabFluid2DView:View {
    let engine:LabFluid2D
    var points=false
    var frame:Int=0 // Publish each completed value snapshot.
    var selected:Int?
    var destinations:Set<Int>=[]
    var rejected:Int?
    var body:some View {
        Canvas(rendersAsynchronously:true) { context,size in
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
            var bulkTops=Array(repeating:Float(0),count:engine.profiles.count)
            let poses=engine.profiles.indices.map { engine.pose($0) }
            for p in engine.particles where p.owner>=0 && p.inBulk {
                bulkTops[p.owner]=max(bulkTops[p.owner],poses[p.owner].local(p.position).y+engine.radius)
            }
            var baseline=Path();baseline.move(to:CGPoint(x:size.width*0.06,y:origin.y+7));baseline.addLine(to:CGPoint(x:size.width*0.94,y:origin.y+7))
            context.stroke(baseline,with:.color(.white.opacity(0.08)),lineWidth:1)
            for index in engine.profiles.indices {
                let base=screen(engine.home(index)),width=CGFloat(engine.profiles[index].radius(0.3))*scale*2.4
                context.fill(Path(ellipseIn:CGRect(x:base.x-width/2,y:base.y+3,width:width,height:7)),with:.color(.black.opacity(0.30)))
                context.fill(cavity(index),with:.linearGradient(Gradient(colors:[Color.cyan.opacity(0.045),.white.opacity(0.012),Color.cyan.opacity(0.02)]),startPoint:CGPoint(x:base.x-width/2,y:base.y),endPoint:CGPoint(x:base.x+width/2,y:base.y)))
            }
            for owner in -1..<engine.profiles.count {
                let owned=engine.particles.filter { $0.owner==owner }
                guard !owned.isEmpty else { continue }
                var liquid=context
                if owner>=0 { liquid.clip(to:cavity(owner)) }
                for color in Set(owned.map(\.color)).sorted() {
                    let ink=FluidBoardSession.color(color)
                    let group=owned.filter { $0.color==color }
                    let pose=owner>=0 ? engine.pose(owner):Lab2DPose(base:.zero)
                    let top=group.filter(\.inBulk).map { pose.local($0.position).y }.max().map { $0+engine.radius } ?? 0
                    let surface=owner>=0 ? engine.surfaces[owner]:Lab2DSurfaceState()
                    let waveActive=owner>=0 && color==surface.color && surface.energy>0.001 && abs(pose.angle)<0.1
                    let halfWidth=owner>=0 ? max(engine.radius,engine.profiles[owner].radius(top)-engine.radius):1
                    let envelope=engine.surfaceEnvelope
                    func wave(_ x:Float)->Float { waveActive ? surface.offset(x:x,halfWidth:halfWidth,envelope:envelope):0 }
                    if points {
                        for p in group {
                            let point=screen(p.position),r=scale*CGFloat(engine.radius)*0.55
                            liquid.fill(Path(ellipseIn:CGRect(x:point.x-r,y:point.y-r,width:r*2,height:r*2)),with:.color(ink))
                        }
                    } else {
                        var blobs=Path(),cores=Path()
                        for (index,p) in group.enumerated() {
                            var rendered=p.position
                            if waveActive && p.inBulk {
                                var local=pose.local(rendered)
                                let weight=labSmooth((local.y-(top-0.22))/0.18)
                                local.y+=wave(local.x)*weight
                                rendered=pose.world(local)
                            }
                            let point=screen(rendered)
                            let speed=sqrt(p.velocity.x*p.velocity.x+p.velocity.y*p.velocity.y)
                            let flying = !p.inBulk
                            let r=scale*CGFloat(engine.separation)*(flying ? 0.62:0.90)
                            let stretch=flying ? CGFloat(min(color==2 ? 2.0:1.75,1+speed*(color==2 ? 0.30:0.24))):1
                            let angle=flying ? atan2(CGFloat(-p.velocity.y),CGFloat(p.velocity.x)):0
                            let oval=Path(ellipseIn:CGRect(x:-r*stretch,y:-r/stretch,width:2*r*stretch,height:2*r/stretch))
                            blobs.addPath(oval,transform:CGAffineTransform(rotationAngle:angle).concatenating(CGAffineTransform(translationX:point.x,y:point.y)))
                            if (color==0 && (flying || index%5==0)) || (color==1 && flying && index%4==0) {
                                let core=scale*CGFloat(engine.radius)*(color==1 ? 0.5:(flying ? 0.28:0.22))
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
                        if color==1 {
                            detail.fill(cores,with:.color(.black.opacity(0.10)))
                            detail.stroke(cores,with:.color(Color(red:1,green:0.88,blue:0.50).opacity(0.5)),lineWidth:0.6)
                        }
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
                                        detail.stroke(bubble,with:.color(Color(red:1,green:0.88,blue:0.50).opacity((0.46+0.16*Double(surface.energy*envelope))*Double(1-pop))),lineWidth:0.8)
                                    }
                                } else {
                                    // A few broad, quiet ribbons provide a silky material cue.
                                    for n in 0..<3 {
                                        var ribbon=Path()
                                        for k in 0...28 {
                                            let f=Float(k)/28,y=bottom+f*height
                                            let wave=sin(f*4.5+t*0.45+Float(n)*2.1)
                                            let x=(Float(n)-1)*profile.radius(y)*0.40+wave*profile.radius(y)*0.20
                                            let point=screen(pose.world(SIMD2(x,y)))
                                            if k==0 { ribbon.move(to:point) } else { ribbon.addLine(to:point) }
                                        }
                                        detail.stroke(ribbon,with:.color(Color(red:0.67,green:1,blue:0.79).opacity(0.14)),style:StrokeStyle(lineWidth:max(1,scale*0.028),lineCap:.round))
                                    }
                                }
                            }
                        }

                        if waveActive && top>0.05 {
                            var crest=Path()
                            for n in 0...36 {
                                let x=(Float(n)/36*2-1)*halfWidth
                                let point=screen(pose.world(SIMD2(x,top+wave(x)-0.012)))
                                if n==0 { crest.move(to:point) } else { crest.addLine(to:point) }
                            }
                            liquid.stroke(crest,with:.color(ink.opacity(Double(surface.energy*envelope)*0.75)),style:StrokeStyle(lineWidth:1.5,lineCap:.round))
                            if color==1 {
                                // Tiny impact bubbles sit just under the moving surface.
                                for n in 0..<5 {
                                    let x=min(halfWidth,max(-halfWidth,surface.impactX+Float(n-2)*0.08))
                                    let y=top+wave(x)-0.025-abs(sin(surface.phase*0.35+Float(n)))*0.045
                                    let point=screen(pose.world(SIMD2(x,y))),r=scale*CGFloat(0.015+Float(n%2)*0.008)
                                    detail.stroke(Path(ellipseIn:CGRect(x:point.x-r,y:point.y-r,width:2*r,height:2*r)),with:.color(Color.yellow.opacity(Double(surface.energy*envelope)*0.55)),lineWidth:0.7)
                                }
                            }
                        }
                    }
                }
            }
            if !points {
                for splash in engine.splashes {
                    let owner=splash.owner,profile=engine.profiles[owner],pose=engine.pose(owner)
                    let local=splash.position
                    let currentTop=bulkTops[owner]
                    guard local.y>currentTop-0.012,local.y<profile.height else { continue }
                    var accent=context;accent.clip(to:cavity(owner))
                    let point=screen(pose.world(local))
                    let fade=Double(max(0,1-splash.age/0.42)*engine.surfaceEnvelope)
                    let r=scale*CGFloat(splash.color==2 ? 0.018:0.012)
                    let dot=Path(ellipseIn:CGRect(x:point.x-r,y:point.y-r,width:2*r,height:2*r))
                    if splash.color==1 { accent.stroke(dot,with:.color(Color.yellow.opacity(fade*0.65)),lineWidth:0.8) }
                    else { accent.fill(dot,with:.color(FluidBoardSession.color(splash.color).opacity(fade*0.85))) }
                }
            }
            for index in engine.profiles.indices {
                let cue:Color?=rejected==index ? .orange:(selected==index ? .cyan:(destinations.contains(index) ? Color(red:0.28,green:0.85,blue:0.79):nil))
                drawGlass(index,context:context,scale:scale,base:screen(engine.pose(index).base),cue:cue)
            }
        }.accessibilityHidden(true)
    }

    private func drawGlass(_ index:Int,context:GraphicsContext,scale:CGFloat,base:CGPoint,cue:Color?) {
        let profile=engine.profiles[index],pose=engine.pose(index)
        var glass=context
        glass.translateBy(x:base.x,y:base.y);glass.rotate(by:.radians(Double(pose.angle)))
        let height=CGFloat(profile.height)*scale,thickness=max(1.7,scale*0.040)
        let width=CGFloat(profile.source.radii.max()! * profile.scale)*scale
        func point(_ side:CGFloat,_ y:Float,_ inset:CGFloat=0)->CGPoint {
            CGPoint(x:side*(CGFloat(profile.radius(y))*scale+inset),y:-CGFloat(y)*scale)
        }
        func contour(_ extra:CGFloat)->Path {
            Path { path in
                path.move(to:point(1,profile.height,extra))
                for k in (0..<128).reversed() { path.addLine(to:point(1,Float(k)/128*profile.height,extra)) }
                let r=CGFloat(profile.radius(0))*scale
                path.addQuadCurve(to:CGPoint(x:-r-extra,y:0),control:CGPoint(x:0,y:extra*2))
                for k in 1...128 { path.addLine(to:point(-1,Float(k)/128*profile.height,extra)) }
            }
        }
        let inner=contour(0),outer=contour(thickness)
        var wall=outer;wall.closeSubpath();var hollow=inner;hollow.closeSubpath();wall.addPath(hollow)
        glass.fill(wall,with:.linearGradient(Gradient(colors:[.white.opacity(0.44),Color.cyan.opacity(0.10),.white.opacity(0.12),Color.cyan.opacity(0.36)]),startPoint:CGPoint(x:-width,y:-height),endPoint:CGPoint(x:width,y:0)),style:FillStyle(eoFill:true))
        glass.stroke(outer,with:.linearGradient(Gradient(colors:[.white.opacity(0.62),Color.cyan.opacity(0.28),.white.opacity(0.45)]),startPoint:CGPoint(x:-width,y:-height),endPoint:CGPoint(x:width,y:0)),style:StrokeStyle(lineWidth:0.9,lineJoin:.round))
        glass.stroke(inner,with:.color(.white.opacity(0.20)),style:StrokeStyle(lineWidth:0.7,lineJoin:.round))
        if let cue { glass.stroke(outer,with:.color(cue.opacity(0.75)),style:StrokeStyle(lineWidth:1.6,lineJoin:.round)) }
        // Narrow reflections sit on the walls, leaving the middle of each color clear.
        for side:CGFloat in [-1,1] {
            var reflection=Path()
            for k in 12...117 {
                let y=Float(k)/128*profile.height,p=point(side,y,-thickness*1.5)
                if k==12 { reflection.move(to:p) } else { reflection.addLine(to:p) }
            }
            glass.stroke(reflection,with:.linearGradient(Gradient(colors:[.white.opacity(side<0 ? 0.26:0.09),.white.opacity(0.015),.white.opacity(0.10)]),startPoint:CGPoint(x:0,y:-height),endPoint:.zero),style:StrokeStyle(lineWidth:max(1,thickness*0.70),lineCap:.round))
        }
        let rim=CGFloat(profile.radius(profile.height))*scale
        let lip=CGRect(x:-rim-thickness,y:-height-thickness*0.75,width:(rim+thickness)*2,height:thickness*1.5)
        glass.stroke(Path(ellipseIn:lip),with:.color(.white.opacity(0.23)),lineWidth:0.8)
        var frontLip=Path();frontLip.move(to:CGPoint(x:-rim-thickness,y:-height))
        frontLip.addQuadCurve(to:CGPoint(x:rim+thickness,y:-height),control:CGPoint(x:0,y:-height+thickness*1.5))
        glass.stroke(frontLip,with:.linearGradient(Gradient(colors:[.white.opacity(0.75),.white.opacity(0.15),.white.opacity(0.5)]),startPoint:CGPoint(x:-rim,y:0),endPoint:CGPoint(x:rim,y:0)),style:StrokeStyle(lineWidth:thickness*0.65,lineCap:.round))
        let bottomRadius=CGFloat(profile.radius(0))*scale
        var foot=Path();foot.move(to:CGPoint(x:-bottomRadius,y:thickness*0.25))
        foot.addQuadCurve(to:CGPoint(x:bottomRadius,y:thickness*0.25),control:CGPoint(x:0,y:thickness*1.3))
        glass.stroke(foot,with:.color(Color.white.opacity(0.5)),style:StrokeStyle(lineWidth:thickness,lineCap:.round))
        for unit in 1...4 {
            let y=profile.level(Float(unit)),r=profile.radius(y)
            var mark=Path();mark.move(to:CGPoint(x:CGFloat(r*0.60)*scale,y:-CGFloat(y)*scale));mark.addLine(to:CGPoint(x:CGFloat(r*0.86)*scale,y:-CGFloat(y)*scale))
            glass.stroke(mark,with:.color(.white.opacity(0.25)),lineWidth:0.8)
        }
    }
}
