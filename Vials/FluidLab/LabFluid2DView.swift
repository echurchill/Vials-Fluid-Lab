import SwiftUI

/// Complete vial layers preserve front-to-back ordering; only moving glass lenses the rear image.
struct LabFluid2DView:View {
    let engine:LabFluid2D
    var points=false
    var frame:Int=0
    var selected:Int?
    var destinations:Set<Int>=[]
    var rejected:Int?
    var capExclusions:Set<Int>=[]
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    private var economy:Bool { ProcessInfo.processInfo.isLowPowerModeEnabled || ProcessInfo.processInfo.thermalState != .nominal }
    var body:some View { GeometryReader { proxy in scene(size:proxy.size) }.accessibilityHidden(true) }
    private func layer(_ owners:Set<Int>,floor:Bool=false)->some View {
        LabFluid2DLayer(engine:engine,points:points,frame:frame,selected:selected,destinations:destinations,rejected:rejected,capExclusions:capExclusions,owners:owners,drawFloor:floor,opaqueGlass:reduceTransparency)
    }
    private func scene(size:CGSize)->AnyView {
        let moves=engine.displayMoves+[engine.game.pending].compactMap {$0}
        let moving=Array(Set(moves.map(\.source))).sorted()
        let layout=LabClassicLayout(size:size,vesselCount:engine.profiles.count),scale=Float(layout.scale)
        var result=AnyView(layer(Set(engine.profiles.indices).subtracting(moving),floor:true))
        for source in moving {
            let rear=result,pose=engine.pose(source),profile=engine.profiles[source]
            let base=SIMD2<Float>(Float(size.width/2)+pose.base.x*scale,Float(layout.base(0).y)-pose.base.y*scale)
            let shader=ShaderLibrary.labVialLens(.float2(base.x,base.y),.float(scale),.float(profile.height),.float(pose.angle),.floatArray(profile.source.radii.map {$0*profile.scale}))
            result=AnyView(ZStack {
                rear.layerEffect(shader,maxSampleOffset:CGSize(width:6,height:6),isEnabled:!points && !reduceTransparency && !economy)
                layer([source])
            })
        }
        return AnyView(ZStack { result;layer([-1]) })
    }
}


/// A planar surface reconstructed from particles; layered glass follows the same interior profile.
private struct LabFluid2DLayer:View {
    let engine:LabFluid2D
    var points=false
    var frame:Int=0 // Publish each completed value snapshot.
    var selected:Int?
    var destinations:Set<Int>=[]
    var rejected:Int?
    var capExclusions:Set<Int>=[]
    var owners:Set<Int>
    var drawFloor=false
    var opaqueGlass=false
    var body:some View {
        Canvas(rendersAsynchronously:false) { context,size in
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
            if drawFloor {
                var baseline=Path();baseline.move(to:CGPoint(x:size.width*0.06,y:origin.y+7));baseline.addLine(to:CGPoint(x:size.width*0.94,y:origin.y+7))
                context.stroke(baseline,with:.color(.white.opacity(0.08)),lineWidth:1)
                for index in engine.profiles.indices {
                    let home=engine.home(index),pose=poses[index]
                    let floor=screen(SIMD2(pose.base.x,home.y))
                    drawLabContactShadow(context:context,center:CGPoint(x:floor.x,y:floor.y+6.5),
                        radius:CGFloat(engine.profiles[index].source.radii.max() ?? 0.5)*scale*1.45,
                        elevation:pose.base.y-home.y)
                }
            }
            for owner in Array(engine.profiles.indices)+[-1] where owners.contains(owner) {
                if owner>=0 {
                    context.fill(cavity(owner),with:.color(Color(red:0.025,green:0.05,blue:0.065).opacity(opaqueGlass ? 1:0.25)))
                }
                defer {
                    if owner>=0 {
                        let cue:Color?=rejected==owner ? .orange:(selected==owner ? .cyan:(destinations.contains(owner) ? Color(red:0.28,green:0.85,blue:0.79):nil))
                        drawGlass(owner,context:context,scale:scale,base:screen(engine.pose(owner).base),cue:cue)
                        let active=Set((engine.displayMoves+[engine.game.pending].compactMap { $0 }).flatMap { [$0.source,$0.destination] })
                        if !capExclusions.union(active).contains(owner),engine.game.state.isComplete(owner),let first=engine.game.state.stacks[owner].first {
                            let profile=engine.profiles[owner],pose=engine.pose(owner)
                            var cap=context;cap.translateBy(x:screen(pose.base).x,y:screen(pose.base).y);cap.rotate(by:.radians(Double(pose.angle)))
                            drawLabPlanarCap(context:&cap,height:profile.height,radius:profile.radius(profile.height)+0.065,
                                scale:scale,color:FluidBoardSession.color(engine.game.state.visualDye(first)))
                        }
                    }
                }
                let owned=engine.particles.filter { $0.owner==owner }
                guard !owned.isEmpty else { continue }
                var liquid=context
                if owner>=0 { liquid.clip(to:cavity(owner)) }
                // Draw the entering density plume after the resident layers so
                // translucent light liquid cannot erase its path to the interface.
                let incoming=engine.game.state.behavior.settlesByDensity && engine.game.pending?.destination==owner ? engine.game.pending.map { engine.game.state.visualDye($0.parcels[0]) }:nil
                let grouped=Dictionary(grouping:owned) { engine.concurrentReveals[$0.parcel] == nil ? $0.color:100+$0.parcel }
                let colors=grouped.keys.sorted { a,b in
                    if a==incoming { return false };if b==incoming { return true };return a<b
                }
                for color in colors {
                    let pigment=color>=36 ? -1:color%12
                    let group=grouped[color]!
                    let mix=engine.transformation
                    let parcel=group.first!.parcel
                    let changes=mix?.parcels.contains(parcel) == true
                    let reveal=engine.concurrentReveals[parcel].map {labSmooth($0/0.5)}
                    let ink=FluidBoardSession.color(reveal != nil ? 36:(changes && mix?.isSeparating == true ? mix!.before.visualDye(parcel):color),mixedWith:reveal != nil ? engine.game.state.visualDye(parcel):(changes ? mix?.after.visualDye(parcel):nil),blend:reveal ?? mix?.blend ?? 0)
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
                            let stretch=flying ? CGFloat(min(pigment==2 ? 2.0:1.75,1+speed*(pigment==2 ? 0.30:0.24))):1
                            let angle=flying ? atan2(CGFloat(-p.velocity.y),CGFloat(p.velocity.x)):0
                            let oval=Path(ellipseIn:CGRect(x:-r*stretch,y:-r/stretch,width:2*r*stretch,height:2*r/stretch))
                            blobs.addPath(oval,transform:CGAffineTransform(rotationAngle:angle).concatenating(CGAffineTransform(translationX:point.x,y:point.y)))
                            if (pigment==0 && (flying || index%9==0)) || (pigment==1 && flying && index%4==0) {
                                let core=scale*CGFloat(engine.radius)*(pigment==1 ? 0.5:(flying ? 0.28:0.22))
                                cores.addEllipse(in:CGRect(x:point.x-core,y:point.y-core,width:core*2,height:core*2))
                            }
                        }
                        func mask(_ ctx:inout GraphicsContext,_ tint:Color) {
                            ctx.addFilter(.alphaThreshold(min:0.40,color:tint))
                            ctx.addFilter(.blur(radius:max(0.5,scale*0.033)))
                            ctx.fill(blobs,with:.color(.white))
                        }
                        if pigment==0 {
                            liquid.drawLayer { glow in
                                glow.addFilter(.blur(radius:scale*0.06))
                                glow.fill(blobs,with:.color(Color.cyan.opacity(0.16)))
                            }
                        }
                        if owner>=0 {
                            var separation=liquid;separation.opacity=opaqueGlass ? 1:0.42
                            separation.drawLayer { surface in mask(&surface,Color(red:0.025,green:0.05,blue:0.065)) }
                        }
                        var body=liquid
                        let resultColor=reveal != nil ? engine.game.state.visualDye(parcel):(changes ? mix!.after.visualDye(parcel):color)
                        let startOpacity:Double=color>=36 ? 1:(color%12==0 ? 0.44:(color%12==2 ? 0.70:0.78))
                        let endOpacity:Double=resultColor>=36 ? 1:(resultColor%12==0 ? 0.44:(resultColor%12==2 ? 0.70:0.78))
                        body.opacity=startOpacity+(endOpacity-startOpacity)*Double(reveal ?? mix?.blend ?? 0)
                        body.drawLayer { surface in mask(&surface,ink) }
                        var detail=liquid
                        detail.clipToLayer { clip in mask(&clip,.white) }
                        if owner>=0 {
                            let center=screen(pose.base),r=CGFloat(engine.profiles[owner].source.radii.max()! * engine.profiles[owner].scale)*scale
                            detail.fill(Path(CGRect(origin:.zero,size:size)),with:.linearGradient(Gradient(colors:[.white.opacity(0.09),.clear,.black.opacity(0.12),.white.opacity(0.04)]),startPoint:CGPoint(x:center.x-r,y:center.y),endPoint:CGPoint(x:center.x+r,y:center.y)))
                        }
                        if pigment==1 {
                            detail.fill(cores,with:.color(.black.opacity(0.10)))
                            detail.stroke(cores,with:.color(Color(red:1,green:0.88,blue:0.50).opacity(0.5)),lineWidth:0.6)
                        }
                        if pigment==0 {
                            detail.drawLayer { glow in
                                glow.addFilter(.blur(radius:1.3))
                                glow.stroke(cores,with:.color(Color.cyan.opacity(0.30)),lineWidth:1.8)
                            }
                            detail.fill(cores,with:.color(Color(red:0.40,green:0.90,blue:1).opacity(0.58)))
                        } else if owner>=0 {
                            let pose=engine.pose(owner),profile=engine.profiles[owner]
                            let local=group.filter(\.inBulk).map { pose.local($0.position) }
                            if let low=local.map(\.y).min(),let high=local.map(\.y).max(),high-low>0.05 {
                                let t=engine.materialTimes[owner]
                                let bottom=low-engine.radius,top=high+engine.radius,height=top-bottom
                                if pigment==1 {
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
                                        detail.stroke(bubble,with:.color(Color(red:1,green:0.88,blue:0.50).opacity((0.32+0.16*Double(surface.energy*envelope))*Double(1-pop))),lineWidth:0.8)
                                    }
                                } else if pigment>=0 && !engine.game.state.behavior.settlesByDensity {
                                    // Keep directional density symbols clear of decorative ribbons.
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
                                        detail.stroke(ribbon,with:.color(Color(red:0.67,green:1,blue:0.79).opacity(0.08)),style:StrokeStyle(lineWidth:max(1,scale*0.028),lineCap:.round))
                                    }
                                }
                            }
                        }

                        if owner>=0 {
                            let local=group.filter(\.inBulk).map {pose.local($0.position)}
                            if let low=local.map(\.y).min(),let high=local.map(\.y).max() {
                                var patterned=detail
                                let base=screen(pose.base)
                                patterned.translateBy(x:base.x,y:base.y);patterned.rotate(by:.radians(Double(pose.angle)))
                                let r=CGFloat(engine.profiles[owner].source.radii.max() ?? 0.5)*scale
                                let bounds=CGRect(x:-r,y:-CGFloat(high+engine.radius)*scale,width:r*2,height:CGFloat(high-low+2*engine.radius)*scale)
                                drawLabDensityPattern(context:patterned,bounds:bounds,scale:scale,dye:color,
                                    nextDye:changes ? mix?.after.visualDye(parcel):nil,blend:mix?.blend ?? 0,offsets:changes ? (mix?.densityPatternOffsets ?? .zero):.zero)
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
                            if pigment==1 {
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
                for splash in engine.splashes where owners.contains(splash.owner) {
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
        for unit in 1...profile.capacity {
            let y=profile.level(Float(unit)),r=profile.radius(y)
            var mark=Path();mark.move(to:CGPoint(x:CGFloat(r*0.60)*scale,y:-CGFloat(y)*scale));mark.addLine(to:CGPoint(x:CGFloat(r*0.86)*scale,y:-CGFloat(y)*scale))
            glass.stroke(mark,with:.color(.white.opacity(0.25)),lineWidth:0.8)
        }
    }
}
