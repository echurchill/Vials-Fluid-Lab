import SwiftUI

/// A decorative, read-only payoff layered over the settled board. It never
/// changes simulation state and ignores touches so completion actions remain
/// immediately available.
struct LabCompletionCelebrationView:View {
    let state:LabBoardState
    let presentation:LabBoardPresentation
    var twoRows=false
    var milestone=false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var start=Date()
    private let duration=1.55

    var body:some View {
        TimelineView(.animation(minimumInterval:1.0/30,paused:reduceMotion)) { timeline in
            let elapsed=reduceMotion ? 0.62:timeline.date.timeIntervalSince(start)
            let progress=min(1,max(0,elapsed/duration))
            Canvas { context,size in
                draw(context:&context,size:size,progress:progress)
            }
            .opacity(reduceMotion ? 0.82:(progress<0.84 ? 1:max(0,(1-progress)/0.16)))
        }
        .onAppear {start=Date()}
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    private func draw(context:inout GraphicsContext,size:CGSize,progress:Double) {
        let profiles=LabBoardLayout.profiles(state:state)
        let layout=LabClassicLayout(size:size,vesselCount:state.stacks.count,twoRows:twoRows)
        let completed=state.stacks.indices.filter {state.isComplete($0) && !state.isHelper($0)}
        guard !completed.isEmpty else {return}
        var glow=context
        glow.blendMode = .plusLighter
        for (rank,index) in completed.enumerated() {
            let delay=Double(rank)*min(0.075,0.52/Double(max(1,completed.count)))
            let local=min(1,max(0,(progress*duration-delay)/0.58))
            guard local>0 else {continue}
            let pulse=sin(local*Double.pi)
            let profile=profiles[index],base=layout.base(index),scale=layout.scale
            let height=CGFloat(profile.height)*scale
            let radius=CGFloat(profile.radii.max() ?? 0.6)*scale
            let color=celebrationColor(index)
            let body=CGRect(x:base.x-radius-5,y:base.y-height-5,width:radius*2+10,height:height+10)
            let outline=Path(roundedRect:body,cornerRadius:max(8,radius*0.42))
            glow.stroke(outline,with:.color(color.opacity(0.12+0.52*pulse)),lineWidth:1.2+2.2*pulse)
            switch presentation {
            case .classic: drawClassic(context:&glow,base:base,top:body.minY,color:color,local:local,rank:rank)
            case .fluid2D: drawPlanar(context:&glow,index:index,base:base,profile:profile,scale:scale,color:color,local:local,rank:rank)
            case .fluid: drawVolumetric(context:&glow,base:base,top:body.minY,radius:radius,color:color,local:local,rank:rank)
            }
        }
        if milestone {drawMilestone(context:&glow,size:size,progress:progress)}
    }

    private func celebrationColor(_ index:Int)->Color {
        guard let parcel=state.stacks[index].last else {return .cyan}
        return FluidBoardSession.color(state.visualDye(parcel))
    }

    private func drawClassic(context:inout GraphicsContext,base:CGPoint,top:CGFloat,color:Color,local:Double,rank:Int) {
        let lift=CGFloat(sin(local*Double.pi))*10
        for n in 0..<(milestone ? 4:3) {
            let side:CGFloat=n.isMultiple(of:2) ? -1:1
            let spread=CGFloat(15+n*7)
            let rise=CGFloat(local)*CGFloat(26+n*8)
            let center=CGPoint(x:base.x+side*spread,y:top-rise-lift)
            let radius=CGFloat(2.5+Double((rank+n)%3))*CGFloat(sin(local*Double.pi))
            context.stroke(spark(center:center,radius:radius),with:.color((n==0 ? Color.white:color).opacity(0.78)),lineWidth:1.4)
        }
    }

    private func drawPlanar(context:inout GraphicsContext,index:Int,base:CGPoint,profile:LabVesselProfile,scale:CGFloat,color:Color,local:Double,rank:Int) {
        let capacity=max(1,state.capacity(index)),units=Float(state.stacks[index].count)
        let level=CGFloat(profile.height(for:profile.usableVolume*units/Float(capacity)))*scale
        let radius=CGFloat(profile.radius(at:Float(level/scale)))*scale*0.82
        let y=base.y-level
        var wave=Path()
        for step in 0...28 {
            let f=CGFloat(step)/28,x=base.x-radius+radius*2*f
            let ripple=sin(f*CGFloat.pi*2+CGFloat(local)*CGFloat.pi*3+CGFloat(rank))*2.2
            let point=CGPoint(x:x,y:y+ripple)
            if step==0 {wave.move(to:point)} else {wave.addLine(to:point)}
        }
        context.stroke(wave,with:.color(.white.opacity(0.22+0.55*sin(local*Double.pi))),style:StrokeStyle(lineWidth:1.6,lineCap:.round))
        for n in 0..<3 {
            let seed=CGFloat((rank*5+n*7)%11)/11
            let rise=CGFloat(local)*(20+seed*22)
            let center=CGPoint(x:base.x+(seed-0.5)*radius*1.45,y:y-rise-4)
            let r=2+seed*2
            context.stroke(Path(ellipseIn:CGRect(x:center.x-r,y:center.y-r,width:r*2,height:r*2)),with:.color(color.opacity(0.68)),lineWidth:1.1)
        }
    }

    private func drawVolumetric(context:inout GraphicsContext,base:CGPoint,top:CGFloat,radius:CGFloat,color:Color,local:Double,rank:Int) {
        let pulse=CGFloat(sin(local*Double.pi))
        let ringRadius=radius*(0.72+CGFloat(local)*0.72)
        let ring=CGRect(x:base.x-ringRadius,y:base.y-5-ringRadius*0.15,width:ringRadius*2,height:ringRadius*0.30)
        context.stroke(Path(ellipseIn:ring),with:.color(color.opacity(Double(pulse)*0.62)),lineWidth:1.5)
        var shimmer=Path();shimmer.move(to:CGPoint(x:base.x-radius*0.58,y:base.y-5));shimmer.addLine(to:CGPoint(x:base.x-radius*0.25,y:top+5))
        context.stroke(shimmer,with:.linearGradient(Gradient(colors:[.clear,.white.opacity(Double(pulse)*0.72),.clear]),startPoint:CGPoint(x:base.x,y:base.y),endPoint:CGPoint(x:base.x,y:top)),lineWidth:2.2)
        for n in 0..<(milestone ? 4:3) {
            let seed=CGFloat((rank*3+n*5)%9)/9
            let rise=CGFloat(local)*(26+seed*28)
            let center=CGPoint(x:base.x+(seed-0.5)*radius*1.3,y:top-rise)
            let r=2.2+seed*2
            context.fill(droplet(center:center,radius:r),with:.color((n==0 ? Color.white:color).opacity(0.72)))
        }
    }

    private func drawMilestone(context:inout GraphicsContext,size:CGSize,progress:Double) {
        let local=min(1,max(0,(progress-0.30)/0.55)),pulse=sin(local*Double.pi)
        guard pulse>0 else {return}
        let center=CGPoint(x:size.width/2,y:size.height*0.18)
        for n in 0..<10 {
            let angle=CGFloat(n)*2*CGFloat.pi/10
            let distance=CGFloat(18+local*62),point=CGPoint(x:center.x+cos(angle)*distance,y:center.y+sin(angle)*distance*0.55)
            context.stroke(spark(center:point,radius:CGFloat(2.5+4*pulse)),with:.color((n.isMultiple(of:2) ? Color.cyan:Color.yellow).opacity(0.68)),lineWidth:1.3)
        }
    }

    private func spark(center:CGPoint,radius:CGFloat)->Path {
        Path {path in
            path.move(to:CGPoint(x:center.x-radius,y:center.y));path.addLine(to:CGPoint(x:center.x+radius,y:center.y))
            path.move(to:CGPoint(x:center.x,y:center.y-radius));path.addLine(to:CGPoint(x:center.x,y:center.y+radius))
        }
    }

    private func droplet(center:CGPoint,radius:CGFloat)->Path {
        Path {path in
            path.move(to:CGPoint(x:center.x,y:center.y-radius*1.45))
            path.addCurve(to:CGPoint(x:center.x,y:center.y+radius),control1:CGPoint(x:center.x+radius*1.15,y:center.y-radius*0.15),control2:CGPoint(x:center.x+radius,y:center.y+radius))
            path.addCurve(to:CGPoint(x:center.x,y:center.y-radius*1.45),control1:CGPoint(x:center.x-radius,y:center.y+radius),control2:CGPoint(x:center.x-radius*1.15,y:center.y-radius*0.15))
            path.closeSubpath()
        }
    }
}
