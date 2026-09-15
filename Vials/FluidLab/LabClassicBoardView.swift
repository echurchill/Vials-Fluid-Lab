import SwiftUI

struct LabClassicLayout {
    let size:CGSize
    var vesselCount:Int = 4
    var scale:CGFloat { min(size.width/(CGFloat(vesselCount)*2.2+0.7),size.height/6.4) }
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
    private var pours:[LabClassicPour] { [pour].compactMap { $0 }+additionalPours }
    private var profiles:[LabVesselProfile] { LabBoardLayout.profiles(count:state.stacks.count) }
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
                    let target=CGPoint(x:receiver.x,y:receiver.y-CGFloat(profiles[pour.move.destination].height)*scale+6)
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
        ctx.fill(cavity,with:.color(.white.opacity(0.035)))
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
            let lower=CGFloat(profile.height(for:profile.usableVolume*units/4))*scale
            units+=amount
            let upper=CGFloat(profile.height(for:profile.usableVolume*units/4))*scale
            let color=FluidBoardSession.color(colorID)
            let band=CGRect(x:-radius,y:-upper,width:radius*2,height:max(0,upper-lower))
            liquid.fill(Path(band),with:.linearGradient(Gradient(colors:[color.opacity(0.85),color,color.opacity(0.82)]),startPoint:CGPoint(x:-radius,y:0),endPoint:CGPoint(x:radius,y:0)))
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
        for unit in 1...4 {
            let y=profile.height(for:profile.usableVolume*Float(unit)/4),r=CGFloat(profile.radius(at:y))*scale
            var mark=Path();mark.move(to:CGPoint(x:r*0.53,y:-CGFloat(y)*scale));mark.addLine(to:CGPoint(x:r*0.90,y:-CGFloat(y)*scale))
            ctx.stroke(mark,with:.color(.white.opacity(0.23)),lineWidth:1)
        }
    }
    private func pose(_ pour:LabClassicPour,layout:LabClassicLayout) -> (base:CGPoint,angle:CGFloat) {
        let source=layout.base(pour.move.source),dest=layout.base(pour.move.destination),scale=layout.scale
        let direction:CGFloat=dest.x>=source.x ? 1:-1
        let h=CGFloat(profiles[pour.move.source].height)*scale
        let receiverH=CGFloat(profiles[pour.move.destination].height)*scale
        let t=pour.time
        let tilt=CGFloat(labSmooth((t-0.95)/0.65))*(1-CGFloat(labSmooth((t-5.2)/0.75)))*1.28*direction
        let mouth=CGPoint(x:dest.x-direction*0.18*scale,y:dest.y-receiverH-0.35*scale)
        let positioned=CGPoint(x:mouth.x-sin(tilt)*h,y:mouth.y+cos(tilt)*h)
        let lift=CGPoint(x:source.x,y:source.y-2.6*scale)
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
