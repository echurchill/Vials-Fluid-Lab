import SwiftUI

/// The frame subscription ends here; the board and comparison controls observe
/// only the slower-changing session. Canvas still receives an immutable value.
struct LabPlanarSurface:View {
    @ObservedObject var display:LabPlanarDisplay
    var animateIdle=false
    var points=false
    var selected:Int?
    var destinations:Set<Int>=[]
    var rejected:Int?
    var body:some View {
        ZStack {
            LabFluid2DView(engine:display.snapshot,points:points,frame:display.frame,selected:selected,destinations:destinations,rejected:rejected)
            if !points && !display.snapshot.busy {
                LabIdleFluidDetail(state:display.snapshot.game.state,profiles:display.snapshot.profiles,enabled:animateIdle)
                    .allowsHitTesting(false).accessibilityHidden(true)
            }
        }
    }
}

struct LabPlanarDiagnostics:View {
    @ObservedObject var display:LabPlanarDisplay
    var body:some View {
        Text("\(display.snapshot.particles.count) particles · \(display.snapshot.cpuMilliseconds,specifier:"%.1f") ms solver CPU")
        Text("Arrived: \(display.snapshot.arrived) · Cleanup: \(display.snapshot.cleanupPercent,specifier:"%.1f")%")
    }
}

/// Only a few clipped highlights drift at rest. Particle positions and layer levels
/// remain unchanged; the full fluid Canvas does not subscribe to this clock.
private struct LabIdleFluidDetail:View {
    let state:LabBoardState
    let profiles:[Lab2DProfile]
    let enabled:Bool
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var economical=ProcessInfo.processInfo.isLowPowerModeEnabled || ProcessInfo.processInfo.thermalState != .nominal
    var body:some View {
        TimelineView(.animation(minimumInterval:1.0/12,paused:!enabled || reduceMotion || economical)) { timeline in
            Canvas { context,size in
                let layout=LabClassicLayout(size:size,vesselCount:profiles.count),scale=layout.scale
                let t=Float(timeline.date.timeIntervalSinceReferenceDate.truncatingRemainder(dividingBy:120))*Float.pi/60
                for index in state.stacks.indices {
                    let stack=state.stacks[index],profile=profiles[index],base=layout.base(index)
                    func screen(_ x:Float,_ y:Float)->CGPoint { CGPoint(x:base.x+CGFloat(x)*scale,y:base.y-CGFloat(y)*scale) }
                    var start=0
                    while start<stack.count {
                        let color=state.colors[stack[start]]
                        var end=start+1
                        while end<stack.count && state.colors[stack[end]]==color { end+=1 }
                        let low=profile.level(Float(start))+0.04,high=profile.level(Float(end))-0.04
                        defer { start=end }
                        guard high>low else { continue }
                        var region=Path()
                        for side:Float in [1,-1] {
                            for k in 0...20 {
                                let f=Float(side>0 ? k:20-k)/20,y=low+(high-low)*f
                                let point=screen(side*max(0,profile.radius(y)-0.045),y)
                                if side==1 && k==0 { region.move(to:point) } else { region.addLine(to:point) }
                            }
                        }
                        region.closeSubpath()
                        var detail=context;detail.clip(to:region)
                        let phase=t+Float(index)*0.9+Float(start)*0.7
                        for n in 0..<3 {
                            let seed=Float(n),f=0.20+seed*0.27+sin(phase*3+seed)*0.045
                            let y=low+(high-low)*f
                            let x=sin(phase*2+seed*2.1)*profile.radius(y)*0.57
                            let point=screen(x,y),radius=scale*CGFloat(color==1 ? 0.023:0.012)
                            let dot=Path(ellipseIn:CGRect(x:point.x-radius,y:point.y-radius,width:radius*2,height:radius*2))
                            if color==1 { detail.stroke(dot,with:.color(.white.opacity(0.24)),lineWidth:0.7) }
                            else { detail.fill(dot,with:.color(.white.opacity(0.22))) }
                        }
                        // Two broad highlights sway slowly inside each color band.
                        for n in 0..<2 {
                            var ribbon=Path()
                            for k in 0...16 {
                                let f=Float(k)/16,y=low+(high-low)*f
                                let x=(Float(n)-0.5)*profile.radius(y)*0.7+sin(f*3+phase*2+Float(n))*profile.radius(y)*0.15
                                let point=screen(x,y)
                                if k==0 { ribbon.move(to:point) } else { ribbon.addLine(to:point) }
                            }
                            detail.stroke(ribbon,with:.color(.white.opacity(color==0 ? 0.10:0.065)),style:StrokeStyle(lineWidth:max(1,scale*0.055),lineCap:.round))
                        }
                        // A faint ripple below the meniscus never changes the silhouette.
                        if end==stack.count {
                            var ripple=Path()
                            for k in 0...24 {
                                let x=(Float(k)/24*2-1)*profile.radius(high)*0.82
                                let point=screen(x,high-0.035+sin(Float(k)/24*2*Float.pi+phase*3)*0.008)
                                if k==0 { ripple.move(to:point) } else { ripple.addLine(to:point) }
                            }
                            detail.stroke(ripple,with:.color(.white.opacity(0.15)),lineWidth:0.7)
                        }
                    }
                }
            }
        }
        .onReceive(NotificationCenter.default.publisher(for:.NSProcessInfoPowerStateDidChange)) { _ in updateEconomy() }
        .onReceive(NotificationCenter.default.publisher(for:ProcessInfo.thermalStateDidChangeNotification)) { _ in updateEconomy() }
    }
    private func updateEconomy() { economical=ProcessInfo.processInfo.isLowPowerModeEnabled || ProcessInfo.processInfo.thermalState != .nominal }
}
