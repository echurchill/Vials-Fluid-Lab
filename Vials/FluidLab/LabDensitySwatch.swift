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

/// Always present in density labs, so transitions never insert a legend row.
struct LabDensityLegend:View {
    @State private var showingHelp=false
    var body:some View {
        HStack(spacing:14) {
            ForEach(LabDensity.allCases,id:\.self) { density in
                HStack(spacing:4) {
                    LabDensitySwatch(color:Color(red:0.05,green:0.58,blue:0.86),density:density).frame(width:20,height:14)
                    Text(density.title).font(.system(size:11))
                }.accessibilityElement(children:.ignore)
                    .accessibilityLabel(density == .light ? "Light: pale upward triangle":(density == .heavy ? "Heavy: dark downward triangle":"Medium: no triangle"))
            }
            Button {showingHelp.toggle()} label: {Image(systemName:"info.circle").frame(width:28,height:24)}
                .buttonStyle(.plain).accessibilityLabel("Density and target guide")
                .popover(isPresented:$showingHelp) {
                    VStack(alignment:.leading,spacing:12) {
                        Text("Reading the liquids").font(.headline)
                        Text("Color identifies the liquid. Triangles identify density: pale upward triangles are light, plain liquid is medium, and dark downward triangles are heavy.")
                        Text("Contents and target strips read left to right, from the bottom of the vial to the top. Match the color, amount and density of every target layer.")
                        Text("A target can look like the right color and still be too heavy or too light. Select its vial to read the difference.")
                    }.font(.callout).padding(20).frame(width:300)
                        .presentationCompactAdaptation(.popover)
                }
        }.foregroundStyle(Color(red:0.80,green:0.88,blue:0.90).opacity(0.85))
    }
}
