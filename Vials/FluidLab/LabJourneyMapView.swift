import SwiftUI

struct LabJourneyMapView:View {
    let current:LabBoardPuzzle?
    let completed:Set<LabBoardPuzzle>
    let choose:(LabBoardPuzzle)->Void
    let close:()->Void
    private let mint=Color(red:0.28,green:0.85,blue:0.79)

    var body:some View {
        GeometryReader { geometry in
            let wide=geometry.size.width>=800
            VStack(spacing:0) {
                HStack(alignment:.top) {
                    VStack(alignment:.leading,spacing:6) {
                        Text("JOURNEY").font(.system(size:10,weight:.bold,design:.monospaced)).tracking(3).foregroundStyle(mint)
                        Text("Choose your path").font(.system(size:28,design:.serif))
                        Text("\(completed.count) of \(LabJourney.stops.count) stops complete · All paths are open")
                            .font(.callout).foregroundStyle(.secondary)
                    }
                    Spacer(minLength:12)
                    Button(action:close) {Image(systemName:"xmark.circle.fill").font(.title2)}
                        .buttonStyle(.plain).accessibilityLabel("Close Journey").keyboardShortcut(.cancelAction)
                }.padding(24)
                Divider()
                ScrollView {
                    mapContent(wide:wide)
                }
            }.background(Color(red:0.026,green:0.043,blue:0.060)).foregroundStyle(Color(red:0.80,green:0.88,blue:0.90))
        }.preferredColorScheme(.dark)
    }

    // Kept separate from ScrollView so the same content can be rendered at
    // compact/wide sizes by the presentation check without a live window.
    func mapContent(wide:Bool)->some View {
                    VStack(spacing:20) {
                        Text("Start with Sorting, choose a branch, then bring your skills together. Progress is shared with the labs.")
                            .font(.callout).foregroundStyle(.secondary).frame(maxWidth:.infinity,alignment:.leading)
                        branch(.sorting,title:"Start with Sorting",subtitle:"Make room. Match colors. Plan ahead.",color:mint)
                            .frame(maxWidth:wide ? 430:.infinity)
                        if wide {
                            rail(merging:false).frame(height:32)
                            HStack(alignment:.top,spacing:18) {
                                branch(.density,title:"Density",subtitle:"Explore how layers settle.",color:.cyan)
                                VStack(spacing:16) {
                                    branch(.mixing,title:"Mixing",subtitle:"Create the color you need.",color:.orange)
                                    Image(systemName:"arrow.down").foregroundStyle(.secondary).accessibilityHidden(true)
                                    branch(.recovery,title:"Recovery",subtitle:"From Mixing: separate and reuse.",color:.purple)
                                }.frame(maxWidth:.infinity)
                                branch(.discovery,title:"Discovery · Optional",subtitle:"From Sorting: uncover hidden colors.",color:.pink)
                            }
                            rail(merging:true).frame(height:32)
                        } else {
                            branch(.density,title:"Branch: Density",subtitle:"From Sorting: explore how layers settle.",color:.cyan)
                            branch(.mixing,title:"Branch: Mixing",subtitle:"From Sorting: create the color you need.",color:.orange)
                            Image(systemName:"arrow.down").foregroundStyle(.secondary).accessibilityHidden(true)
                            branch(.recovery,title:"Recovery",subtitle:"Continue from Mixing: separate and reuse.",color:.purple)
                            branch(.discovery,title:"Optional branch: Discovery",subtitle:"From Sorting: uncover hidden colors.",color:.pink)
                        }
                        branch(.crossover,title:"Bring your skills together",subtitle:"Combine what Density and Recovery taught you.",color:mint)
                            .frame(maxWidth:wide ? 600:.infinity)
                        Text("Looking for more practice? Every lab is still available from the game board.")
                            .font(.callout).foregroundStyle(.secondary)
                    }.padding(24).frame(maxWidth:1100).frame(maxWidth:.infinity)
    }

    private func branch(_ discipline:LabDiscipline,title:String,subtitle:String,color:Color)->some View {
        VStack(alignment:.leading,spacing:12) {
            Text(title).font(.headline).foregroundStyle(color)
            Text(subtitle).font(.caption).foregroundStyle(.secondary).fixedSize(horizontal:false,vertical:true)
            let stops=LabJourney.branch(discipline)
            ForEach(stops) { stop in
                stopCard(stop,color:color)
                if stop.id != stops.last?.id {
                    Image(systemName:"arrow.down").font(.caption).frame(maxWidth:.infinity).foregroundStyle(color.opacity(0.6)).accessibilityHidden(true)
                }
            }
        }.frame(maxWidth:.infinity,alignment:.topLeading)
    }

    private func stopCard(_ stop:LabJourneyStop,color:Color)->some View {
        let done=completed.contains(stop.puzzle),selected=current==stop.puzzle
        return Button {choose(stop.puzzle)} label: {
            VStack(alignment:.leading,spacing:8) {
                HStack(alignment:.firstTextBaseline,spacing:8) {
                    Image(systemName:done ? "checkmark.circle.fill":"circle").foregroundStyle(done ? mint:color)
                    Text(stop.puzzle.title).font(.system(size:15,weight:.semibold))
                    Spacer(minLength:0)
                }
                Text(stop.lesson).font(.system(size:12)).foregroundStyle(.secondary).fixedSize(horizontal:false,vertical:true)
                if selected {Text("CURRENT STOP").font(.system(size:9,weight:.bold,design:.monospaced)).tracking(1).foregroundStyle(mint)}
            }.frame(maxWidth:.infinity,alignment:.leading).padding(14)
                .background(selected ? mint.opacity(0.12):Color.white.opacity(0.045),in:RoundedRectangle(cornerRadius:14))
                .overlay(RoundedRectangle(cornerRadius:14).stroke(selected ? mint:color.opacity(0.25),lineWidth:selected ? 2:1))
                .contentShape(RoundedRectangle(cornerRadius:14))
        }.buttonStyle(.plain).accessibilityElement(children:.ignore).accessibilityAddTraits(.isButton)
            .accessibilityLabel(stop.puzzle.title+". "+stop.lesson+(done ? " Completed.":" Not completed.")+(selected ? " Current stop.":""))
            .accessibilityHint("Open this Journey stop")
            .accessibilityIdentifier("journey.stop."+stop.puzzle.rawValue)
    }

    private func rail(merging:Bool)->some View {
        Canvas { context,size in
            let center=size.width/2,ports=merging ? [size.width/6,center]:[size.width/6,center,size.width*5/6]
            var path=Path()
            for x in ports {
                path.move(to:CGPoint(x:merging ? x:center,y:0))
                path.addLine(to:CGPoint(x:merging ? x:center,y:size.height/2))
                path.addLine(to:CGPoint(x:merging ? center:x,y:size.height/2))
                path.addLine(to:CGPoint(x:merging ? center:x,y:size.height))
            }
            context.stroke(path,with:.color(mint.opacity(0.4)),style:StrokeStyle(lineWidth:2,lineCap:.round,lineJoin:.round))
        }.accessibilityHidden(true)
    }
}
