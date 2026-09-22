import SwiftUI

/// Screen-space guidance shared by every presentation. It only decorates the
/// existing hit rectangles; it cannot change vessel geometry or intercept taps.
struct LabMachineConnectionOverlay:View {
    let tool:LabApparatus
    let rects:[CGRect]
    let tint:Color

    var body:some View {
        Canvas { context,size in
            let inputs=tool.inputs.filter {rects.indices.contains($0)}
            let outputs=tool.outputs.filter {rects.indices.contains($0)}
            let members=Set(inputs+outputs)
            for index in members.sorted() {
                let rect=rects[index].insetBy(dx:-4,dy:-4)
                let outline=Path(roundedRect:rect,cornerRadius:20)
                let isInput=inputs.contains(index) && tool.kind != .densityModifier
                let style=StrokeStyle(lineWidth:2.5,lineCap:.round,dash:isInput ? [5,4]:[])
                context.stroke(outline,with:.color(.black.opacity(0.8)),style:StrokeStyle(lineWidth:5,lineCap:.round,dash:style.dash))
                context.stroke(outline,with:.color(tint),style:style)
            }
            // Routes sit below the vessels so they never obscure the liquid.
            // Each output has an upward arrowhead pointing into its vessel.
            for input in inputs {
                for output in outputs where input != output {
                    let from=CGPoint(x:rects[input].midX,y:rects[input].maxY+6)
                    let to=CGPoint(x:rects[output].midX,y:rects[output].maxY+7)
                    let bend=min(size.height-8,max(from.y,to.y)+30)
                    var route=Path();route.move(to:from)
                    route.addCurve(to:to,control1:CGPoint(x:from.x,y:bend),control2:CGPoint(x:to.x,y:bend))
                    context.stroke(route,with:.color(.black.opacity(0.85)),style:StrokeStyle(lineWidth:5,lineCap:.round))
                    context.stroke(route,with:.color(tint.opacity(0.9)),style:StrokeStyle(lineWidth:2.5,lineCap:.round))
                }
            }
            for output in outputs {
                let tip=CGPoint(x:rects[output].midX,y:rects[output].maxY+6)
                var arrow=Path();arrow.move(to:tip)
                arrow.addLine(to:CGPoint(x:tip.x-5,y:tip.y+8));arrow.addLine(to:CGPoint(x:tip.x+5,y:tip.y+8));arrow.closeSubpath()
                context.fill(arrow,with:.color(tint))
            }
        }
    }
}
