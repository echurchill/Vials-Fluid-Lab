import SwiftUI
import simd

struct LabClassicLayout {
    let size:CGSize
    var vesselCount:Int = 4
    // Reserve fixed side room for an outward shared pour. The board never
    // changes scale when a source lifts or returns.
    var scale:CGFloat { min(size.width/(CGFloat(vesselCount)*2.2+4.4),size.height/6.4) }
    func base(_ index:Int) -> CGPoint { CGPoint(x:size.width/2+CGFloat(LabBoardLayout.homes(count:vesselCount)[index].x)*scale,y:size.height*0.82) }
    func hitRect(_ index:Int,profile:LabVesselProfile) -> CGRect {
        let point=base(index),radius=CGFloat(profile.radii.max() ?? 0.6)*scale
        return CGRect(x:point.x-radius-8,y:point.y-CGFloat(profile.height)*scale-8,width:radius*2+16,height:CGFloat(profile.height)*scale+16)
    }
}

/// Flat SwiftUI paths, gradients, and an animated stream; no Metal view or particles.
struct LabClassicBoardView:View {
    let state:LabBoardState
    let pour:LabClassicPour?
    var additionalPours:[LabClassicPour]=[]
    var capExclusions:Set<Int>=[]
    private var pours:[LabClassicPour] { [pour].compactMap { $0 }+additionalPours }
    private var profiles:[LabVesselProfile] { LabBoardLayout.profiles(capacities:state.capacities) }
    var body:some View {
        Canvas { context,size in
            let layout=LabClassicLayout(size:size,vesselCount:state.stacks.count),scale=layout.scale
            let tray=CGRect(x:size.width*0.06,y:layout.base(0).y-10,width:size.width*0.88,height:40)
            context.stroke(Path(ellipseIn:tray),with:.color(.white.opacity(0.08)),lineWidth:1)
            let moving=Set(pours.map { $0.move.source })
            for index in state.stacks.indices where !moving.contains(index) { drawVial(index,context:context,layout:layout) }
            for pour in pours {
                let pose=pose(pour,layout:layout)
                if pour.progress>0 && pour.progress<1 {
                    let h=CGFloat(profiles[pour.move.source].height)*scale
                    let mouth=CGPoint(x:pose.base.x+sin(pose.angle)*h,y:pose.base.y-cos(pose.angle)*h)
                    let receiver=layout.base(pour.move.destination)
                    let destination=pour.move.destination,profile=profiles[destination]
                    let surface=profile.height(for:profile.usableVolume*displayedUnits(in:destination)/Float(state.capacity(destination)))
                    // Follow the growing liquid body into the cavity. Stopping
                    // at the rim made the stream look as though it vanished at
                    // the mouth instead of joining the accumulating fluid.
                    let target=CGPoint(x:receiver.x,y:receiver.y-CGFloat(surface)*scale-1)
                    var stream=Path();stream.move(to:mouth)
                    stream.addCurve(to:target,control1:CGPoint(x:mouth.x,y:mouth.y+20),control2:CGPoint(x:target.x,y:target.y-24))
                    let envelope=min(1,min(CGFloat(pour.progress)*12,CGFloat(1-pour.progress)*12))
                    let color=FluidBoardSession.color(pour.move.color)
                    context.stroke(stream,with:.color(color.opacity(0.20)),style:StrokeStyle(lineWidth:scale*0.22*envelope,lineCap:.round))
                    context.stroke(stream,with:.linearGradient(Gradient(colors:[color.opacity(0.7),color]),startPoint:mouth,endPoint:target),style:StrokeStyle(lineWidth:scale*0.11*envelope,lineCap:.round))
                    context.stroke(stream,with:.color(.white.opacity(0.22)),style:StrokeStyle(lineWidth:scale*0.02*envelope,lineCap:.round))
                }
                drawVial(pour.move.source,context:context,layout:layout)
            }
        }.accessibilityHidden(true)
    }
    private func displayedUnits(in index:Int)->Float {
        var units=Float(state.stacks[index].count)
        for pour in pours {
            if pour.move.source == index { units-=Float(pour.move.amount)*pour.progress }
            if pour.move.destination == index { units+=Float(pour.move.amount)*pour.progress }
        }
        return min(Float(state.capacity(index)),max(0,units))
    }
    private func shape(_ profile:LabVesselProfile,scale:CGFloat) -> Path {
        Path { path in
            for i in profile.radii.indices {
                let y=CGFloat(i)/CGFloat(profile.radii.count-1)*CGFloat(profile.height)*scale
                let point=CGPoint(x:CGFloat(profile.radii[i])*scale,y:-y)
                if i==0 { path.move(to:point) } else { path.addLine(to:point) }
            }
            for i in profile.radii.indices.reversed() {
                let y=CGFloat(i)/CGFloat(profile.radii.count-1)*CGFloat(profile.height)*scale
                path.addLine(to:CGPoint(x:-CGFloat(profile.radii[i])*scale,y:-y))
            }
            path.closeSubpath()
        }
    }
    private func drawVial(_ index:Int,context:GraphicsContext,layout:LabClassicLayout) {
        var ctx=context
        let profile=profiles[index],scale=layout.scale
        var base=layout.base(index),angle:CGFloat=0
        if let pour=pours.first(where:{$0.move.source==index}) { let transform=pose(pour,layout:layout);base=transform.base;angle=transform.angle }
        ctx.translateBy(x:base.x,y:base.y);ctx.rotate(by:.radians(angle))
        let cavity=shape(profile,scale:scale),radius=CGFloat(profile.radii.max() ?? 0.6)*scale
        ctx.fill(cavity,with:.color(Color(red:0.025,green:0.045,blue:0.06).opacity(0.82)))
        ctx.stroke(cavity,with:.color(.black.opacity(0.28)),lineWidth:5)
        var liquid=ctx;liquid.clip(to:cavity)
        var amounts=state.stacks[index].map { (state.colors[$0],Float(1)) }
        for pour in pours {
            if index == pour.move.source {
                amounts=amounts.enumerated().map { position,pair in
                    (pair.0,position>=amounts.count-pour.move.amount ? 1-pour.progress:1)
                }
            } else if index == pour.move.destination { amounts.append((pour.move.color,Float(pour.move.amount)*pour.progress)) }
        }
        var units:Float=0,run=0
        while run<amounts.count {
            let colorID=amounts[run].0
            var amount=amounts[run].1,end=run+1
            while end<amounts.count && amounts[end].0 == colorID { amount+=amounts[end].1;end+=1 }
            let capacity=Float(state.capacities[index])
            let lower=CGFloat(profile.height(for:profile.usableVolume*units/capacity))*scale
            units+=amount
            let upper=CGFloat(profile.height(for:profile.usableVolume*units/capacity))*scale
            let color=FluidBoardSession.color(colorID)
            let band=CGRect(x:-radius,y:-upper,width:radius*2,height:max(0,upper-lower))
            liquid.fill(Path(band),with:.linearGradient(Gradient(colors:[color.opacity(0.96),color,color.opacity(0.95)]),startPoint:CGPoint(x:-radius,y:0),endPoint:CGPoint(x:radius,y:0)))
            if amount>0.001 {
                let r=CGFloat(profile.radius(at:Float(upper/scale)))*scale
                liquid.fill(Path(ellipseIn:CGRect(x:-r,y:-upper-2,width:r*2,height:4)),with:.color(color.opacity(0.9)))
                var highlight=Path();highlight.move(to:CGPoint(x:-r,y:-upper));highlight.addLine(to:CGPoint(x:r,y:-upper))
                liquid.stroke(highlight,with:.color(.white.opacity(0.20)),lineWidth:1)
            }
            run=end
        }
        ctx.stroke(cavity,with:.linearGradient(Gradient(colors:[.white.opacity(0.4),.indigo.opacity(0.65),.white.opacity(0.20)]),startPoint:CGPoint(x:-radius,y:-CGFloat(profile.height)*scale),endPoint:CGPoint(x:radius,y:0)),lineWidth:2.5)
        var rim=Path();let topRadius=CGFloat(profile.radii.last!)*scale,top = -CGFloat(profile.height)*scale
        rim.move(to:CGPoint(x:-topRadius,y:top));rim.addLine(to:CGPoint(x:topRadius,y:top))
        ctx.stroke(rim,with:.color(.white.opacity(0.48)),style:StrokeStyle(lineWidth:3,lineCap:.round))
        for unit in 1...state.capacities[index] {
            let y=profile.height(for:profile.usableVolume*Float(unit)/Float(state.capacities[index])),r=CGFloat(profile.radius(at:y))*scale
            var mark=Path();mark.move(to:CGPoint(x:r*0.53,y:-CGFloat(y)*scale));mark.addLine(to:CGPoint(x:r*0.90,y:-CGFloat(y)*scale))
            ctx.stroke(mark,with:.color(.white.opacity(0.23)),lineWidth:1)
        }
        let excluded=capExclusions.union(pours.flatMap { [$0.move.source,$0.move.destination] })
        if !excluded.contains(index),state.isComplete(index),let first=state.stacks[index].first {
            drawLabPlanarCap(context:&ctx,height:profile.height,radius:profile.radii.last!+0.065,
                scale:scale,color:FluidBoardSession.color(state.colors[first]))
        }
    }
    private func pose(_ pour:LabClassicPour,layout:LabClassicLayout) -> (base:CGPoint,angle:CGFloat) {
        let source=layout.base(pour.move.source),dest=layout.base(pour.move.destination),scale=layout.scale
        let direction:CGFloat=pour.approach==0 ? (dest.x>=source.x ? 1:-1):CGFloat(pour.approach)
        let h=CGFloat(profiles[pour.move.source].height)*scale
        let receiverH=CGFloat(profiles[pour.move.destination].height)*scale
        let t=pour.time
        let tilt=CGFloat(labSmooth((t-0.95)/0.65))*(1-CGFloat(labSmooth((t-5.2)/0.75)))*1.28*direction
        let extraCapacity=CGFloat(max(0,max(state.capacity(pour.move.source),state.capacity(pour.move.destination))-4))
        let standardSeparation=0.18+0.18*extraCapacity
        let separation=pour.approach==0 ? standardSeparation:max(0.46,standardSeparation)+0.70*(1-CGFloat(labSmooth(Float(abs(tilt)))))
        let mouth=CGPoint(x:dest.x-direction*separation*scale,y:dest.y-receiverH-0.35*scale)
        let positioned=CGPoint(x:mouth.x-sin(tilt)*h,y:mouth.y+cos(tilt)*h)
        let travelClearance=CGFloat((profiles.map(\.height).max() ?? 2.35)+0.35)
        let lift=CGPoint(x:source.x,y:source.y-travelClearance*scale)
        func mix(_ a:CGPoint,_ b:CGPoint,_ value:Float) -> CGPoint {
            let f=CGFloat(labSmooth(value));return CGPoint(x:a.x+(b.x-a.x)*f,y:a.y+(b.y-a.y)*f)
        }
        let liftProgress=CGFloat(labLiftProgress(t/0.5))
        var point=CGPoint(x:source.x+(lift.x-source.x)*liftProgress,y:source.y+(lift.y-source.y)*liftProgress)
        if t>=0.5 { point=mix(lift,positioned,(t-0.5)/0.45) }
        if t>=5.95 {
            let raised=CGPoint(x:mouth.x,y:lift.y)
            point=mix(positioned,raised,(t-5.95)/0.35)
            if t>=6.3 { point=mix(raised,lift,(t-6.3)/0.45) }
            if t>=6.75 { point=mix(lift,source,(t-6.75)/0.45) }
        }
        return (point,tilt)
    }
}

/// Draw a sealed stopper in a vial-local coordinate system. Keeping it in the
/// same graphics layer as its glass lets later, foreground vials occlude it.
func drawLabPlanarCap(context:inout GraphicsContext,height:Float,radius:Float,scale:CGFloat,color:Color) {
    func project(_ point:SIMD3<Float>)->CGPoint {
        CGPoint(x:CGFloat(point.x)*scale,y:-CGFloat(point.y-point.z*0.23)*scale)
    }
    func ring(_ y:Float,_ r:Float)->[SIMD3<Float>] {
        (0..<48).map { n in let a=Float(n)*2*Float.pi/48;return SIMD3(cos(a)*r,y,sin(a)*r) }
    }
    func path(_ points:[SIMD3<Float>])->Path {
        Path { p in
            for (n,point) in points.enumerated() {
                if n==0 { p.move(to:project(point)) } else { p.addLine(to:project(point)) }
            }
            p.closeSubpath()
        }
    }
    let bottom=ring(height-0.015,radius),top=ring(height+0.18,radius),eye=SIMD3<Float>(0,5,20)
    let sides=(0..<48).sorted { simd_dot(bottom[$0],eye)<simd_dot(bottom[$1],eye) }
    for n in sides {
        let next=(n+1)%48,face=path([bottom[n],bottom[next],top[next],top[n]])
        let angle=(Float(n)+0.5)*2*Float.pi/48,light=max(0,-cos(angle)*0.55+sin(angle)*0.45)
        context.fill(face,with:.color(color))
        context.fill(face,with:.color(.black.opacity(Double(0.48-light*0.40))))
        if n%2==0,simd_dot(SIMD3(cos(angle),0,sin(angle)),eye)>0 {
            var groove=Path();groove.move(to:project(bottom[n]));groove.addLine(to:project(top[n]))
            context.stroke(groove,with:.color(.white.opacity(0.14)),lineWidth:0.6)
        }
    }
    let lid=path(top),left=project(SIMD3(-radius,height+0.18,0)),right=project(SIMD3(radius,height+0.18,0))
    context.fill(lid,with:.color(color))
    context.fill(lid,with:.linearGradient(Gradient(colors:[.white.opacity(0.5),.white.opacity(0.12),.black.opacity(0.15)]),startPoint:left,endPoint:right))
    context.stroke(lid,with:.color(.white.opacity(0.55)),lineWidth:0.8)
    context.stroke(path(ring(height+0.182,radius*0.79)),with:.color(.black.opacity(0.20)),lineWidth:0.7)
}
