import SwiftUI
import simd

struct LabClassicLayout {
    let size:CGSize
    var vesselCount:Int = 4
    var twoRows=false
    // Reserve fixed side room for an outward shared pour. The board never
    // changes scale when a source lifts or returns.
    var columnCount:Int {twoRows ? (vesselCount+1)/2:vesselCount}
    var scale:CGFloat { min(size.width/(CGFloat(columnCount)*2.2+4.4),size.height/(twoRows ? 10.2:6.4)) }
    func base(_ index:Int) -> CGPoint {
        let home=LabBoardLayout.homes(count:vesselCount,twoRows:twoRows)[index]
        let baseline=size.height*(twoRows ? 0.88:0.82)
        return CGPoint(x:size.width/2+CGFloat(home.x)*scale,y:baseline-CGFloat(home.y-0.18)*scale)
    }
    var rows:[Range<Int>] {LabBoardLayout.rowRanges(count:vesselCount,twoRows:twoRows)}
    func hitRect(_ index:Int,profile:LabVesselProfile,includesHandle:Bool=false,includesValveLid:Bool=false) -> CGRect {
        let point=base(index)
        let bodyRadius=CGFloat(profile.radii.max() ?? 0.6)
        let lidRadius=CGFloat(profile.radii.last ?? 0.6)+0.07
        let radius=max(bodyRadius,includesValveLid ? lidRadius:0)*scale
        let handle=includesHandle ? scale*0.48:0
        let lidHeight=includesValveLid ? scale*0.20:0
        return CGRect(x:point.x-radius-8,y:point.y-CGFloat(profile.height)*scale-8-lidHeight,
                      width:radius*2+16+handle,height:CGFloat(profile.height)*scale+16+lidHeight)
    }
}

/// Flat SwiftUI paths, gradients, and an animated stream; no Metal view or particles.
struct LabClassicBoardView:View {
    let state:LabBoardState
    let pour:LabClassicPour?
    var additionalPours:[LabClassicPour]=[]
    var capExclusions:Set<Int>=[]
    var transformation:LabApparatusTransition?
    var reveals:[Int:Float]=[:]
    var twoRows=false
    private var pours:[LabClassicPour] { [pour].compactMap { $0 }+additionalPours }
    private var profiles:[LabVesselProfile] { LabBoardLayout.profiles(state:state) }
    var body:some View {
        Canvas { context,size in
            let layout=LabClassicLayout(size:size,vesselCount:state.stacks.count,twoRows:twoRows),scale=layout.scale
            for index in state.stacks.indices {
                let home=layout.base(index)
                let base=pours.first(where:{$0.move.source==index}).map {pose($0,layout:layout).base} ?? home
                drawLabContactShadow(context:context,center:CGPoint(x:base.x,y:home.y+6.5),
                    radius:CGFloat(profiles[index].radii.max() ?? 0.5)*scale*1.45,
                    elevation:Float((home.y-base.y)/scale))
            }
            let moving=Set(pours.map { $0.move.source })
            for index in state.stacks.indices where !moving.contains(index) { drawVial(index,context:context,layout:layout) }
            if let transformation { drawMixStreams(transformation,context:context,layout:layout) }
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
                    let color=FluidBoardSession.color(state.visualDye(pour.move.parcels[0]))
                    context.stroke(stream,with:.color(color.opacity(0.20)),style:StrokeStyle(lineWidth:scale*0.22*envelope,lineCap:.round))
                    context.stroke(stream,with:.linearGradient(Gradient(colors:[color.opacity(0.7),color]),startPoint:mouth,endPoint:target),style:StrokeStyle(lineWidth:scale*0.11*envelope,lineCap:.round))
                    context.stroke(stream,with:.color(.white.opacity(0.22)),style:StrokeStyle(lineWidth:scale*0.02*envelope,lineCap:.round))
                }
                drawVial(pour.move.source,context:context,layout:layout)
            }
        }.accessibilityHidden(true)
    }
    private func drawMixStreams(_ transformation:LabApparatusTransition,context:GraphicsContext,layout:LabClassicLayout) {
        guard !transformation.isDensityChange,transformation.gathered>0,transformation.gathered<1 else {return}
        if transformation.isSeparating {
            let source=transformation.apparatus.inputs[0],base=layout.base(source),scale=layout.scale
            let mouth=CGPoint(x:base.x,y:base.y-CGFloat(profiles[source].height)*scale)
            for output in transformation.apparatus.outputs {
                let home=layout.base(output),target=CGPoint(x:home.x,y:home.y-CGFloat(profiles[output].height)*scale)
                let top=min(mouth.y,target.y)-scale*0.55
                var path=Path();path.move(to:mouth);path.addCurve(to:target,control1:CGPoint(x:mouth.x,y:top),control2:CGPoint(x:target.x,y:top))
                let parcel=transformation.after.stacks[output][0],color=FluidBoardSession.color(transformation.before.visualDye(parcel),mixedWith:transformation.after.visualDye(parcel),blend:transformation.blend)
                let envelope=CGFloat(sin(transformation.gathered*Float.pi))
                context.stroke(path,with:.color(color.opacity(0.9)),style:StrokeStyle(lineWidth:scale*0.10*envelope,lineCap:.round))
            }
            return
        }
        let destination=layout.base(transformation.output),scale=layout.scale
        let target=CGPoint(x:destination.x,y:destination.y-CGFloat(profiles[transformation.output].height)*scale)
        let envelope=CGFloat(sin(transformation.gathered*Float.pi))
        for input in transformation.apparatus.inputs {
            let base=layout.base(input),mouth=CGPoint(x:base.x,y:base.y-CGFloat(profiles[input].height)*scale)
            let top=min(mouth.y,target.y)-scale*0.65
            var path=Path();path.move(to:mouth)
            path.addCurve(to:target,control1:CGPoint(x:mouth.x,y:top),control2:CGPoint(x:target.x,y:top))
            let color=FluidBoardSession.color(state.visualDye(state.stacks[input][0]))
            context.stroke(path,with:.color(color.opacity(0.25)),style:StrokeStyle(lineWidth:scale*0.22*envelope,lineCap:.round))
            context.stroke(path,with:.color(color.opacity(0.9)),style:StrokeStyle(lineWidth:scale*0.10*envelope,lineCap:.round))
        }
    }
    private func densityJoinedUnits(_ pour:LabClassicPour)->Float {
        let crossesLighter=state.densityInsertionIndex(for:pour.move)<state.stacks[pour.move.destination].count
        let front=crossesLighter ? labSmooth(pour.progress/0.10):1
        return Float(pour.move.amount)*pour.progress*front
    }
    private func displayedUnits(in index:Int)->Float {
        var units=Float(state.stacks[index].count)
        for pour in pours {
            if pour.move.source == index { units-=Float(pour.move.amount)*pour.progress }
            if pour.move.destination == index { units+=Float(pour.move.amount)*pour.progress }
        }
        return min(Float(state.capacity(index)),max(0,units))
    }
    private func valveLidOpenness(_ index:Int)->Float {
        pours.filter {$0.move.destination==index}.map {pour in
            let opening=labSmooth((pour.time-0.35)/0.35)
            let closing=1-labSmooth((pour.time-5.35)/0.45)
            return opening*closing
        }.max() ?? 0
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
        if state.isHelper(index) {
            let h=CGFloat(profile.height)*scale,outer=radius+(state.capacity(index)==3 ? scale*0.48:scale*0.40)
            var handle=Path();handle.move(to:CGPoint(x:radius*0.78,y:-h*0.78))
            handle.addCurve(to:CGPoint(x:radius*0.78,y:-h*0.24),control1:CGPoint(x:outer,y:-h*0.82),control2:CGPoint(x:outer,y:-h*0.19))
            ctx.stroke(handle,with:.color(.black.opacity(0.28)),style:StrokeStyle(lineWidth:max(7,scale*0.12),lineCap:.round))
            ctx.stroke(handle,with:.linearGradient(Gradient(colors:[.white.opacity(0.55),.cyan.opacity(0.18),.white.opacity(0.38)]),startPoint:CGPoint(x:radius,y:-h),endPoint:CGPoint(x:outer,y:0)),style:StrokeStyle(lineWidth:max(3,scale*0.055),lineCap:.round))
        }
        ctx.fill(cavity,with:.color(Color(red:0.025,green:0.045,blue:0.06).opacity(0.82)))
        ctx.stroke(cavity,with:.color(.black.opacity(0.28)),lineWidth:5)
        var liquid=ctx;liquid.clip(to:cavity)
        var amounts=state.stacks[index].map { (reveals[$0] != nil ? 100+$0:(transformation?.revealedParcels.contains($0) == true ? 37:state.visualDye($0)),Float(1)) }
        for pour in pours {
            if index == pour.move.source {
                amounts=amounts.enumerated().map { position,pair in
                    (pair.0,position>=amounts.count-pour.move.amount ? 1-pour.progress:1)
                }
            } else if index == pour.move.destination {
                if state.behavior.settlesByDensity {
                    amounts=state.densityReceiverLayers(destination:index,arrivals:pours.filter {$0.move.destination==index}.map {($0.move,densityJoinedUnits($0))}).map { (state.visualDye($0.parcel),$0.units) }
                } else { amounts.append((state.visualDye(pour.move.parcels[0]),Float(pour.move.amount)*pour.progress)) }
            }
        }
        if let transformation,!transformation.isDensityChange {
            if transformation.apparatus.inputs.contains(index) {amounts=amounts.map {($0.0,$0.1*(1-transformation.gathered))}}
            if transformation.isSeparating,transformation.apparatus.outputs.contains(index) {
                amounts=transformation.after.stacks[index].map {(transformation.after.visualDye($0),transformation.gathered)}
            } else if index==transformation.output {amounts=transformation.apparatus.inputs.map {(state.visualDye(state.stacks[$0][0]),transformation.gathered)}}
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
            let mixingOutput=transformation?.output==index && transformation?.isSeparating != true
            let revealed=state.stacks[index].first {transformation?.revealedParcels.contains($0) == true}
            let finalDye:Int?=colorID>=100 ? state.visualDye(colorID-100):colorID==37 ? revealed.map {state.visualDye($0)}:(mixingOutput && transformation?.isRevealing != true ? transformation.map {$0.after.visualDye($0.after.stacks[index][0])}:nil)
            let color=FluidBoardSession.color(colorID>=100 ? 36:colorID,mixedWith:finalDye,blend:colorID>=100 ? labSmooth((reveals[colorID-100] ?? 0)/0.5):(transformation?.blend ?? 0))
            let band=CGRect(x:-radius,y:-upper,width:radius*2,height:max(0,upper-lower))
            liquid.fill(Path(band),with:.linearGradient(Gradient(colors:[color.opacity(0.96),color,color.opacity(0.95)]),startPoint:CGPoint(x:-radius,y:0),endPoint:CGPoint(x:radius,y:0)))
            var patterned=liquid;patterned.clip(to:Path(band))
            drawLabDensityPattern(context:patterned,bounds:band,scale:scale,dye:colorID,
                nextDye:finalDye,blend:transformation?.blend ?? 0,offsets:mixingOutput ? (transformation?.densityPatternOffsets ?? .zero):.zero)
            if amount>0.001 {
                let r=CGFloat(profile.radius(at:Float(upper/scale)))*scale
                liquid.fill(Path(ellipseIn:CGRect(x:-r,y:-upper-2,width:r*2,height:4)),with:.color(color.opacity(0.9)))
                var highlight=Path();highlight.move(to:CGPoint(x:-r,y:-upper));highlight.addLine(to:CGPoint(x:r,y:-upper))
                liquid.stroke(highlight,with:.color(.white.opacity(0.20)),lineWidth:1)
            }
            run=end
        }
        if let transformation,transformation.isDensityChange,index==transformation.output,transformation.agitation>0 {
            let top=CGFloat(profile.height(for:profile.usableVolume*Float(state.stacks[index].count)/Float(state.capacity(index))))*scale
            var current=liquid;current.clip(to:Path(CGRect(x:-radius,y:-top,width:radius*2,height:top)))
            let direction:CGFloat=transformation.apparatus.direction == .heavier ? -1:1
            for n in 0..<4 {
                let travel=CGFloat(transformation.time)*0.42*direction+CGFloat(n)/4
                let f=travel-floor(travel),y=top*f
                let r=CGFloat(profile.radius(at:Float(y/scale)))*scale*0.78
                var path=Path();path.move(to:CGPoint(x:-r,y:-y))
                path.addQuadCurve(to:CGPoint(x:r,y:-y),control:CGPoint(x:0,y:-y-direction*scale*0.18))
                current.stroke(path,with:.color(.white.opacity(Double(transformation.agitation)*0.13)),style:StrokeStyle(lineWidth:1.5,lineCap:.round))
            }
        }
        if let transformation,!transformation.isDensityChange,!transformation.isSeparating,index==transformation.output,transformation.agitation>0 {
            let top=CGFloat(profile.height(for:profile.usableVolume*2*transformation.gathered/Float(state.capacity(index))))*scale
            var swirl=liquid;swirl.clip(to:Path(CGRect(x:-radius,y:-top,width:radius*2,height:top)))
            for (n,input) in transformation.apparatus.inputs.enumerated() {
                let parcel=state.stacks[input][0],color=FluidBoardSession.color(state.visualDye(parcel),mixedWith:transformation.after.visualDye(parcel),blend:transformation.blend)
                for ribbon in 0..<3 {
                    var path=Path()
                    for k in 0...48 {
                        let f=CGFloat(k)/48,y=top*f
                        let phase=Double(f)*8+Double(transformation.time)*6+Double(n)*Double.pi+Double(ribbon)*0.8
                        let x=sin(phase)*CGFloat(profile.radius(at:Float(y/scale)))*scale*0.75
                        let point=CGPoint(x:x,y:-y)
                        if k==0 {path.move(to:point)} else {path.addLine(to:point)}
                    }
                    swirl.stroke(path,with:.color(color.opacity(Double(transformation.agitation)*0.8)),style:StrokeStyle(lineWidth:scale*0.12,lineCap:.round))
                }
            }
        }
        if state.behavior.settlesByDensity {
            for pour in pours where pour.move.destination==index && pour.progress>0 && pour.progress<1 {
                let bands=state.densityReceiverBands(destination:index,arrivals:pours.filter {$0.move.destination==index}.map {($0.move,densityJoinedUnits($0))})
                let landingUnits=bands[pour.move.parcels.last!]?.y ?? 0
                let surface=profile.height(for:profile.usableVolume*displayedUnits(in:index)/Float(state.capacity(index)))
                let landing=profile.height(for:profile.usableVolume*landingUnits/Float(state.capacity(index)))
                let front=surface+(landing-surface)*labSmooth(pour.progress/0.10)
                let envelope=min(1,min(pour.progress*16,(1-pour.progress)*16))
                let color=FluidBoardSession.color(state.visualDye(pour.move.parcels[0]))
                var plume=Path();plume.move(to:CGPoint(x:0,y:-CGFloat(surface)*scale))
                plume.addCurve(to:CGPoint(x:0,y:-CGFloat(front)*scale),control1:CGPoint(x:scale*0.07,y:-CGFloat(surface)*scale),control2:CGPoint(x:-scale*0.09,y:-CGFloat(front)*scale))
                liquid.stroke(plume,with:.color(color.opacity(0.30)),style:StrokeStyle(lineWidth:scale*0.24*CGFloat(envelope),lineCap:.round))
                liquid.stroke(plume,with:.color(color.opacity(0.92)),style:StrokeStyle(lineWidth:scale*0.11*CGFloat(envelope),lineCap:.round))
            }
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
        let excluded=capExclusions.union(pours.flatMap { [$0.move.source,$0.move.destination] }).union(transformation?.vessels ?? [])
        if let key=state.valvePigment(index) {
            drawLabPlanarValveLid(context:&ctx,height:profile.height,radius:profile.radii.last!+0.07,
                scale:scale,color:FluidBoardSession.color(key),pigment:key,openness:valveLidOpenness(index))
        } else if !excluded.contains(index),state.isComplete(index),let first=state.stacks[index].first {
            drawLabPlanarCap(context:&ctx,height:profile.height,radius:profile.radii.last!+0.065,
                scale:scale,color:FluidBoardSession.color(state.visualDye(first)))
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
        let topBaseline=layout.rows.compactMap { $0.first.map(layout.base) }.map(\.y).min() ?? source.y
        let lift=CGPoint(x:source.x,y:topBaseline-travelClearance*scale)
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

/// A permanent, keyed valve lid. It hinges upward for a valid incoming pour;
/// its high-contrast motif makes the key distinguishable without hue alone.
func drawLabPlanarValveLid(context:inout GraphicsContext,height:Float,radius:Float,scale:CGFloat,
                           color:Color,pigment:Int,openness:Float) {
    let open=labSmooth(openness),angle = -open*1.42
    let bottom=height+0.015,top=height+0.20,hinge=SIMD3<Float>(radius,bottom,0)
    func rotate(_ point:SIMD3<Float>)->SIMD3<Float> {
        let p=point-hinge,c=cos(angle),s=sin(angle)
        return hinge+SIMD3(c*p.x-s*p.y,s*p.x+c*p.y,p.z)
    }
    func project(_ point:SIMD3<Float>)->CGPoint {
        let p=rotate(point)
        return CGPoint(x:CGFloat(p.x)*scale,y:-CGFloat(p.y-p.z*0.23)*scale)
    }
    func ring(_ y:Float,_ r:Float)->[SIMD3<Float>] {
        (0..<48).map { n in let a=Float(n)*2*Float.pi/48;return SIMD3(cos(a)*r,y,sin(a)*r) }
    }
    func path(_ points:[SIMD3<Float>],closed:Bool=true)->Path {
        Path { p in
            for (n,point) in points.enumerated() {
                if n==0 {p.move(to:project(point))} else {p.addLine(to:project(point))}
            }
            if closed {p.closeSubpath()}
        }
    }
    // The hinge is a permanent physical joint. The complete solid stopper,
    // including its sidewall and lower face, rotates around it.
    let pivot=project(hinge),mount=project(SIMD3(radius-0.10,height,0))
    var arm=Path();arm.move(to:mount);arm.addLine(to:pivot)
    context.stroke(arm,with:.color(.black.opacity(0.78)),style:StrokeStyle(lineWidth:max(4,scale*0.075),lineCap:.round))
    context.stroke(arm,with:.color(color.opacity(0.86)),style:StrokeStyle(lineWidth:max(2,scale*0.035),lineCap:.round))
    let lower=ring(bottom,radius),upper=ring(top,radius),eye=SIMD3<Float>(0,5,20)
    let sides=(0..<48).sorted {simd_dot(rotate(lower[$0]),eye)<simd_dot(rotate(lower[$1]),eye)}
    for n in sides {
        let next=(n+1)%48,face=path([lower[n],lower[next],upper[next],upper[n]])
        let a=(Float(n)+0.5)*2*Float.pi/48,light=max(0,-cos(a)*0.55+sin(a)*0.45)
        context.fill(face,with:.color(color))
        context.fill(face,with:.color(.black.opacity(Double(0.48-light*0.40))))
        if n%2==0 {
            var groove=Path();groove.move(to:project(lower[n]));groove.addLine(to:project(upper[n]))
            context.stroke(groove,with:.color(.white.opacity(0.14)),lineWidth:0.6)
        }
    }
    let lid=path(upper),left=project(SIMD3(-radius,top,0)),right=project(SIMD3(radius,top,0))
    context.fill(lid,with:.color(color))
    context.fill(lid,with:.linearGradient(Gradient(colors:[.white.opacity(0.50),.white.opacity(0.12),.black.opacity(0.18)]),startPoint:left,endPoint:right))
    var marked=context;marked.clip(to:lid)
    let mark=Color.white.opacity(0.76),line=max(1.2,scale*0.022),motif=radius*0.48
    switch (pigment%4+4)%4 {
    case 0:
        marked.stroke(path((0..<40).map {n in let a=Float(n)*2*Float.pi/40;return SIMD3(cos(a)*motif,top,sin(a)*motif)}),with:.color(mark),lineWidth:line)
    case 1:
        marked.stroke(path([SIMD3(-motif,top,0),SIMD3(motif,top,0)],closed:false),with:.color(mark),lineWidth:line)
    case 2:
        marked.stroke(path([SIMD3(0,top,-motif),SIMD3(0,top,motif)],closed:false),with:.color(mark),lineWidth:line)
    default:
        marked.stroke(path([SIMD3(-motif,top,-motif),SIMD3(motif,top,motif)],closed:false),with:.color(mark),lineWidth:line)
        marked.stroke(path([SIMD3(motif,top,-motif),SIMD3(-motif,top,motif)],closed:false),with:.color(mark),lineWidth:line)
    }
    context.stroke(lid,with:.color(.white.opacity(0.62)),lineWidth:max(1,scale*0.018))
    context.stroke(path(ring(top+0.002,radius*0.79)),with:.color(.black.opacity(0.20)),lineWidth:0.7)
    context.fill(Path(ellipseIn:CGRect(x:pivot.x-max(2,scale*0.035),y:pivot.y-max(2,scale*0.035),width:max(4,scale*0.07),height:max(4,scale*0.07))),with:.color(.white.opacity(0.55)))
}

/// Flatten a soft radial footprint into a floor ellipse; no offscreen blur pass.
func drawLabContactShadow(context:GraphicsContext,center:CGPoint,radius:CGFloat,elevation:Float) {
    let shadow=LabContactShadow(elevation:elevation),width=radius*CGFloat(shadow.scale)
    var ctx=context
    ctx.translateBy(x:center.x,y:center.y)
    ctx.scaleBy(x:width,y:6*CGFloat(shadow.scale))
    // A softly lit patch of floor gives the dark contact core contrast even
    // on the almost-black planar board; no hard ring or outline.
    ctx.fill(Path(ellipseIn:CGRect(x:-1.35,y:-1.35,width:2.7,height:2.7)),
        with:.radialGradient(Gradient(stops:[
            .init(color:Color(red:0.30,green:0.40,blue:0.44).opacity(0.38),location:0),
            .init(color:Color(red:0.30,green:0.40,blue:0.44).opacity(0.30),location:0.55),
            .init(color:.clear,location:1)]),center:.zero,startRadius:0,endRadius:1.35))
    ctx.fill(Path(ellipseIn:CGRect(x:-1,y:-1,width:2,height:2)),
        with:.radialGradient(Gradient(stops:[.init(color:.black.opacity(Double(shadow.opacity)),location:0),
                .init(color:.black.opacity(Double(shadow.opacity)*0.85),location:0.5),.init(color:.clear,location:1)]),
            center:.zero,startRadius:0,endRadius:1))
}

/// Density changes the motif, never the pigment. A row is centered in even a
/// thin layer, with bounded symbol sizes and a small, deterministic variation.
@MainActor func drawLabDensityPattern(context:GraphicsContext,bounds:CGRect,scale:CGFloat,dye:Int,nextDye:Int?=nil,blend:Float=0,offsets:SIMD2<Float> = .zero) {
    let f=Double(min(1,max(0,blend))),before=max(0,dye/12),after=max(0,(nextDye ?? dye)/12)
    let light=(before==1 ? 1-f:0)+(after==1 ? f:0),heavy=(before==2 ? 1-f:0)+(after==2 ? f:0)
    guard light+heavy>0.001,bounds.height>2,bounds.width>2 else {return}
    let spacing=max(12,min(21,scale*0.34)),rows=max(1,Int(bounds.height/spacing))
    let pigment=FluidBoardSession.color(dye,mixedWith:nextDye,blend:blend)
    for row in 0..<rows {
        let y=bounds.minY+bounds.height*(CGFloat(row)+0.5)/CGFloat(rows)
        let offset:CGFloat=row%2==0 ? 0:spacing*0.5
        let columns=Int(ceil(bounds.width/spacing))+1
        for column in -columns...columns {
            let x=bounds.midX+CGFloat(column)*spacing+offset
            guard x>=bounds.minX,x<=bounds.maxX else {continue}
            let variation=CGFloat(abs(column*7+row*3)%5)/4
            let radius=min(max(3,scale*(0.070+0.019*variation)),bounds.height*0.42)
            func triangle(_ direction:CGFloat,_ offset:Float)->Path {
                let center=y-CGFloat(offset)*scale
                return Path {p in p.move(to:CGPoint(x:x,y:center-direction*radius));p.addLine(to:CGPoint(x:x-radius*0.866,y:center+direction*radius*0.5));p.addLine(to:CGPoint(x:x+radius*0.866,y:center+direction*radius*0.5));p.closeSubpath()}
            }
            if light>0 {
                let p=triangle(1,offsets.x)
                context.fill(p,with:.color(.white.opacity(0.88*light)))
                context.stroke(p,with:.color(pigment.opacity(0.95*light)),style:StrokeStyle(lineWidth:0.85,lineJoin:.round))
            }
            if heavy>0 {
                let p=triangle(-1,offsets.y)
                context.fill(p,with:.color(pigment.opacity(heavy)))
                context.fill(p,with:.color(.black.opacity(0.78*heavy)))
            }
        }
    }
}
