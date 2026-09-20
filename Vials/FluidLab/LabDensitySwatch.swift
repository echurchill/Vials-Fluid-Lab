import SwiftUI

/// Shared by the actual contents and requested target, so matching material
/// uses the same pigment and density symbol in both rows. Parent vial buttons
/// already provide the full spoken material and target descriptions.
struct LabDensitySwatch:View {
    let color:Color
    var density:LabDensity?
    var target=false
    var body:some View {
        Canvas { context,size in
            let bounds=CGRect(origin:.zero,size:size)
            let capsule=Path(roundedRect:bounds,cornerRadius:size.height/2)
            context.fill(capsule,with:.color(color))
            if target {
                context.stroke(Path(roundedRect:bounds.insetBy(dx:0.5,dy:0.5),cornerRadius:max(0,size.height/2-0.5)),
                    with:.color(.white.opacity(0.5)),lineWidth:1)
            }
            guard let density,density != .medium else {return}
            let width=min(10,max(0,size.width-4)),height=min(9,max(0,size.height-3))
            let x=size.width/2,y=size.height/2,direction:CGFloat=density == .light ? 1:-1
            var triangle=Path()
            triangle.move(to:CGPoint(x:x,y:y-direction*height/2))
            triangle.addLine(to:CGPoint(x:x-width/2,y:y+direction*height/2))
            triangle.addLine(to:CGPoint(x:x+width/2,y:y+direction*height/2))
            triangle.closeSubpath()
            if density == .light {
                context.fill(triangle,with:.color(.white.opacity(0.94)))
                context.stroke(triangle,with:.color(color),style:StrokeStyle(lineWidth:0.8,lineJoin:.round))
            } else {
                context.fill(triangle,with:.color(color))
                context.fill(triangle,with:.color(.black.opacity(0.78)))
            }
        }.accessibilityHidden(true)
    }
}
