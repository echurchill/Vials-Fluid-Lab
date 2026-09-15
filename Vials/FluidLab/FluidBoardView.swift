import SwiftUI
import MetalKit
import Combine

private enum BoardSheet:String,Identifiable { case classic,study;var id:String { rawValue } }

struct FluidBoardView:View {
    @StateObject private var session=FluidBoardSession(allowsConcurrentPours:true)
    @State private var sheet:BoardSheet?
    @State private var comparison:LabPourExample?
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    private let ink=Color(red:0.80,green:0.88,blue:0.90)
    private let accent=Color(red:0.28,green:0.85,blue:0.79)
    var body:some View {
        GeometryReader { geometry in
            let compact=geometry.size.width<680
            VStack(spacing:0) {
                HStack {
                    VStack(alignment:.leading,spacing:4) {
                        Text("VIALS / FLUID LAB").font(.system(size:10,weight:.semibold,design:.monospaced)).tracking(3).foregroundStyle(ink.opacity(0.5))
                        Text(session.puzzle.title).font(.system(size:compact ? 28:34,design:.serif)).foregroundStyle(ink)
                    }
                    Spacer()
                    Button { session.diagnostics.toggle() } label: { Image(systemName:"slider.horizontal.3").frame(width:34,height:34) }
                        .buttonStyle(.plain).accessibilityLabel("Board diagnostics")
                    Menu {
                        Toggle("Pouring sound",isOn:$session.soundEnabled)
                        #if os(iOS)
                        Toggle("Haptics",isOn:$session.hapticsEnabled)
                        #endif
                        Picker("Fluid detail",selection:$session.quality) { ForEach(LabRenderQuality.allCases,id:\.self) { Text($0.title).tag($0) } }.disabled(session.busy || session.presentation != .fluid)
                        Divider()
                        Button(session.lastPour == nil ? "Compare a pour":"Compare last pour") { comparison=session.comparisonExample }.disabled(!session.canComparePour)
                        Button("Pour study") { sheet = .study }
                        Button("Original game") { sheet = .classic }
                    } label: { Image(systemName:"ellipsis.circle").frame(width:32,height:32) }.menuStyle(.borderlessButton).fixedSize().accessibilityLabel("Board options")
                }.padding(.horizontal,compact ? 20:32).padding(.top,20).padding(.bottom,12)
                HStack(spacing:12) {
                    Picker("Presentation",selection:Binding(get:{session.presentation},set:session.changePresentation)) {
                        ForEach(LabBoardPresentation.allCases,id:\.self) { Text($0.title).tag($0) }
                    }.pickerStyle(.segmented).frame(maxWidth:330)
                    Picker("Pace",selection:Binding(get:{session.pace},set:session.changePace)) {
                        ForEach(LabBoardPace.allCases,id:\.self) { Text($0.title).tag($0) }
                    }.pickerStyle(.segmented).frame(maxWidth:220)
                    Spacer(minLength:0)
                    Menu {
                        ForEach(LabBoardPuzzle.allCases,id:\.self) { puzzle in Button("\(puzzle.number). \(puzzle.title)\(session.hasCompleted(puzzle) ? " ✓":"")") { session.changePuzzle(puzzle) } }
                    } label: { Image(systemName:"square.grid.2x2").frame(width:28,height:28) }.accessibilityLabel("Choose puzzle")
                }.disabled(session.busy).padding(.horizontal,compact ? 20:32).padding(.bottom,8)
                HStack { Text(session.puzzle.detail);Spacer();Text("\(session.completedPuzzleCount) complete") }.font(.system(size:10,design:.monospaced)).foregroundStyle(ink.opacity(0.55)).padding(.horizontal,compact ? 20:32)
                HStack {
                    Text(session.paused ? "Paused":session.phase).font(.system(size:compact ? 19:24,weight:.light,design:.serif))
                    Spacer()
                    Text("\(session.moveCount) \(session.moveCount == 1 ? "move":"moves")").font(.system(size:12,design:.monospaced)).foregroundStyle(ink.opacity(0.6))
                }.padding(.horizontal,compact ? 20:32).frame(height:38)
                GeometryReader { board in
                    ZStack {
                        if session.presentation == .classic { LabClassicBoardView(state:session.state,pour:session.classicPour,additionalPours:session.concurrentClassicPours) }
                        else if session.presentation == .fluid2D { LabPlanarSurface(display:session.planarDisplay,animateIdle:!session.paused && !session.busy && scenePhase == .active && sheet == nil && comparison == nil,points:session.points,selected:session.selected,destinations:session.validDestinations,rejected:session.rejectedVial) }
                        else if let renderer=session.renderer { BoardMetalSurface(renderer:renderer).accessibilityHidden(true) }
                        else { ContentUnavailableView("Metal unavailable",systemImage:"cube.transparent",description:Text(session.error ?? "Unable to start the fluid renderer.")) }
                        LabVialCaps(state:session.state,planarProfiles:session.fluid2D.profiles,presentation:session.presentation,orbit:Float(session.orbit),
                            uncapped:Set([session.selected].compactMap { $0 }+session.activeMoves.flatMap { [$0.source,$0.destination] }))
                            .allowsHitTesting(false).accessibilityHidden(true)
                        ForEach(session.state.stacks.indices,id:\.self) { index in
                            let rect=hitRect(index,size:board.size)
                            Button { session.select(index) } label: {
                                RoundedRectangle(cornerRadius:20)
                                    .fill(Color.white.opacity(0.001))
                                    .overlay(alignment:.bottom) {
                                        Label(cueLabel(index),systemImage:cueSymbol(index)).font(.system(size:10,weight:.semibold))
                                            .fixedSize().padding(.horizontal,7).padding(.vertical,4).background(.black.opacity(0.75),in:Capsule())
                                            .foregroundStyle(cueColor(index) == .clear ? ink.opacity(0.75):cueColor(index)).opacity(cueLabel(index).isEmpty ? 0:1).offset(y:17)
                                    }
                                    .overlay {
                                        let target=session.validDestinations.contains(index)
                                        let outline=RoundedRectangle(cornerRadius:20)
                                        let style=StrokeStyle(lineWidth:session.selected==index ? 3:2.5,lineCap:.round,dash:target ? [6,4]:[])
                                        outline.stroke(.black.opacity(cueColor(index) == .clear ? 0:0.45),style:StrokeStyle(lineWidth:style.lineWidth+2,lineCap:.round,dash:style.dash))
                                        outline.stroke(cueColor(index).opacity(0.95),style:style)
                                    }
                            }
                            .buttonStyle(LabVialPressStyle()).frame(width:rect.width,height:rect.height).position(x:rect.midX,y:rect.midY)
                            .disabled(!session.canTap(index))
                            .accessibilityLabel(session.accessibility(index)).accessibilityValue(session.vialComplete(index) && cueLabel(index).isEmpty ? "Complete":cueLabel(index))
                        }
                        if session.diagnostics {
                            diagnostics.frame(maxWidth:.infinity,maxHeight:.infinity,alignment:.topLeading).padding(14)
                        }
                        if let error=session.error { Text(error).font(.callout).padding().background(.ultraThinMaterial,in:RoundedRectangle(cornerRadius:12)) }
                    }
                }.frame(minHeight:220)
                VStack(spacing:14) {
                    LazyVGrid(columns:Array(repeating:GridItem(.flexible(),spacing:8),count:compact && session.state.stacks.count>4 ? 3:session.state.stacks.count),spacing:8) {
                        ForEach(session.state.stacks.indices,id:\.self) { index in
                            Button { session.select(index) } label: {
                                VStack(spacing:5) {
                                    HStack(spacing:5) {
                                        Text(FluidBoardSession.letter(index)).font(.system(size:13,weight:.semibold,design:.monospaced))
                                        Text(session.vialComplete(index) ? "✓":"\(session.state.stacks[index].count) / 4").font(.system(size:11,design:.monospaced)).foregroundStyle(ink.opacity(0.7))
                                    }
                                    HStack(spacing:3) {
                                        ForEach(0..<4,id:\.self) { layer in
                                            Capsule().fill(layer<session.state.stacks[index].count ? FluidBoardSession.color(session.state.colors[session.state.stacks[index][layer]]):ink.opacity(0.09)).frame(height:4)
                                        }
                                    }
                                }.frame(maxWidth:.infinity).padding(.vertical,12).padding(.horizontal,9)
                                    .background(cueLabel(index).isEmpty ? ink.opacity(0.04):cueColor(index).opacity(0.13),in:RoundedRectangle(cornerRadius:10))
                                    .overlay(RoundedRectangle(cornerRadius:10).stroke(cueColor(index).opacity(0.65),lineWidth:1))
                                    .scaleEffect(!reduceMotion && session.selected==index ? 1.025:1)
                                    .offset(x:!reduceMotion && session.rejectedVial==index ? 3:0)
                                    .animation(reduceMotion ? nil:.easeInOut(duration:0.18),value:session.selected)
                                    .animation(reduceMotion ? nil:.easeInOut(duration:0.12),value:session.rejectedVial)
                            }.buttonStyle(LabVialPressStyle()).disabled(!session.canTap(index))
                            .accessibilityLabel("Select "+session.accessibility(index)).accessibilityValue(session.vialComplete(index) && cueLabel(index).isEmpty ? "Complete":cueLabel(index))
                        }
                    }
                    if session.solved,let next=session.puzzle.next {
                        Button("Next: \(next.title)",systemImage:"arrow.right") { session.nextPuzzle() }.buttonStyle(.borderedProminent).tint(accent).foregroundStyle(.black)
                    }
                    Text(session.notice).font(.system(size:12)).foregroundStyle(ink.opacity(0.65)).frame(maxWidth:.infinity,minHeight:30).multilineTextAlignment(.center)
                    HStack(spacing:12) {
                        Button("Undo",systemImage:"arrow.uturn.backward") { session.undo() }.disabled(session.busy || session.moveCount == 0)
                        Button("Hint",systemImage:"lightbulb") { session.hint() }.disabled(session.busy || session.solved)
                        Spacer(minLength:0)
                        Button { session.togglePause() } label: { Image(systemName:session.paused ? "play.fill":"pause.fill") }.accessibilityLabel(session.paused ? "Resume board":"Pause board")
                        Button(session.solved ? "Play again":"Reset",systemImage:"arrow.counterclockwise") { session.reset() }
                    }.buttonStyle(.bordered).controlSize(.regular)
                }.padding(.horizontal,compact ? 20:32).padding(.vertical,18).background(Color(red:0.065,green:0.060,blue:0.075))
            }.background(Color(red:0.026,green:0.043,blue:0.060)).foregroundStyle(ink)
        }
        .preferredColorScheme(.dark)
        .task { await session.runTrialIfRequested() }
        .onAppear { if reduceMotion { session.paused=true;session.renderer?.paused=true } }
        .onChange(of:sheet) { _,value in session.setSuspended(value != nil || comparison != nil || scenePhase != .active) }
        .onChange(of:scenePhase) { _,value in session.setSuspended(value != .active || sheet != nil || comparison != nil) }
        .onChange(of:comparison?.id) { _,value in session.setSuspended(value != nil || sheet != nil || scenePhase != .active) }
        .sheet(item:$comparison) { example in LabPourComparisonView(example:example) }
        .sheet(item:$sheet) { item in
            ZStack(alignment:.topTrailing) {
                if item == .study { FluidLabView() } else { ContentView() }
                Button("Return to board",systemImage:"xmark.circle.fill") { sheet=nil }.buttonStyle(.bordered).padding()
            }.frame(minWidth:360,minHeight:640)
        }
    }
    private func cueLabel(_ index:Int)->String {
        if let item=session.pourQueue.items.first(where:{$0.move.source==index}) { return item.started ? "Pouring":"Queued" }
        if session.busy && !session.allowsConcurrentPours { return "" }
        if session.rejectedVial==index { return "Cannot pour" }
        if session.selected==index { return "Selected" }
        if session.hintTarget==index { return "Hint" }
        if session.validDestinations.contains(index) { return "Pour here" }
        return ""
    }
    private func cueSymbol(_ index:Int)->String {
        if let item=session.pourQueue.items.first(where:{$0.move.source==index}) { return item.started ? "drop":"clock" }
        if session.rejectedVial==index { return "xmark.circle" }
        if session.selected==index { return "drop.fill" }
        if session.hintTarget==index { return "lightbulb" }
        return session.validDestinations.contains(index) ? "arrow.down":"checkmark.circle"
    }
    private func cueColor(_ index:Int)->Color {
        if session.busy && !session.allowsConcurrentPours { return .clear }
        if session.rejectedVial==index || session.hintTarget==index { return .orange }
        if session.selected==index || session.validDestinations.contains(index) { return accent }
        return .clear
    }
    private var diagnostics:some View {
        VStack(alignment:.leading,spacing:7) {
            Text(session.presentation.title.uppercased()+" STUDY").font(.system(size:9,weight:.bold,design:.monospaced)).tracking(2)
            if session.presentation == .fluid {
            Text("\(session.renderer?.particleCount ?? 0) particles · \(session.metrics.gpuMilliseconds,specifier:"%.1f") ms GPU")
            Text("Outside: \(session.metrics.outside) · Wrong layer: \(session.metrics.wrongParcel)")
            Text("Pour assist: \(session.metrics.guided) particles")
            if session.captured>0 { Text("Captured: \(session.captured*100,specifier:"%.1f")% · Cleanup: \(session.correction)") }
            }
            if session.presentation == .fluid2D {
                LabPlanarDiagnostics(display:session.planarDisplay)
                Toggle("Show particles",isOn:$session.points).toggleStyle(.switch).controlSize(.mini)
            }
            Toggle("Slow motion",isOn:$session.slow).toggleStyle(.switch).controlSize(.mini)
            if session.presentation == .fluid {
            Toggle("Show particles",isOn:$session.points).toggleStyle(.switch).controlSize(.mini)
            HStack { Text("View");Slider(value:$session.orbit,in: -0.3...0.4).frame(width:120) }
            }
            Button(session.measurementActive ? "Finish measurement":"Record session") { session.toggleMeasurement() }
            if let report=session.reportURL { ShareLink("Share measurements",item:report) }
        }.font(.system(size:10,design:.monospaced)).padding(12).background(.ultraThinMaterial,in:RoundedRectangle(cornerRadius:12))
    }
    private func hitRect(_ index:Int,size:CGSize) -> CGRect {
        let profiles=LabBoardLayout.profiles(count:session.state.stacks.count)
        if session.presentation == .fluid2D {
            let layout=LabClassicLayout(size:size,vesselCount:profiles.count),profile=session.fluid2D.profiles[index]
            let base=layout.base(index),radius=CGFloat((profile.source.radii.max() ?? 0.6)*profile.scale)*layout.scale
            return CGRect(x:base.x-radius-8,y:base.y-CGFloat(profile.height)*layout.scale-8,width:radius*2+16,height:CGFloat(profile.height)*layout.scale+16)
        }
        if session.presentation == .classic { return LabClassicLayout(size:size,vesselCount:session.state.stacks.count).hitRect(index,profile:profiles[index]) }
        let matrix=LabBoardLayout.camera(aspect:Float(size.width/max(size.height,1)),azimuth:Float(session.orbit),vesselCount:session.state.stacks.count).0
        let home=LabBoardLayout.homes(count:session.state.stacks.count)[index],r=(profiles[index].radii.max() ?? 0.6)+0.05
        var xs:[CGFloat]=[],ys:[CGFloat]=[]
        for x in [-r,r] { for z in [-r,r] { for y:Float in [0,profiles[index].height] {
            let p=matrix*SIMD4(home+SIMD3(x,y,z),1)
            xs.append(CGFloat(p.x/p.w+1)*size.width/2);ys.append(CGFloat(1-p.y/p.w)*size.height/2)
        }}}
        return CGRect(x:xs.min()!-6,y:ys.min()!-6,width:xs.max()!-xs.min()!+12,height:ys.max()!-ys.min()!+12)
    }
}

#if os(macOS)
struct BoardMetalSurface:NSViewRepresentable {
    let renderer:LabBoardRenderer
    func makeNSView(context:Context) -> MTKView { makeBoardView(renderer) }
    func updateNSView(_ view:MTKView,context:Context) {}
    static func dismantleNSView(_ view:MTKView,coordinator:()) { view.isPaused=true;view.delegate=nil }
}
#else
struct BoardMetalSurface:UIViewRepresentable {
    let renderer:LabBoardRenderer
    func makeUIView(context:Context) -> MTKView { makeBoardView(renderer) }
    func updateUIView(_ view:MTKView,context:Context) {}
    static func dismantleUIView(_ view:MTKView,coordinator:()) { view.isPaused=true;view.delegate=nil }
}
#endif
@MainActor private func makeBoardView(_ renderer:LabBoardRenderer) -> MTKView {
    let view=MTKView(frame:.zero,device:renderer.device)
    view.colorPixelFormat = .bgra8Unorm_srgb;view.preferredFramesPerSecond=60
    view.autoResizeDrawable=false;view.delegate=renderer
    return view
}

/// Completion is a physical-looking closure, separate from interactive pour hints.
/// This static overlay shares the board camera and never observes particle frames.
private struct LabVialCaps:View {
    let state:LabBoardState
    let planarProfiles:[Lab2DProfile]
    let presentation:LabBoardPresentation
    let orbit:Float
    let uncapped:Set<Int>
    var body:some View {
        Canvas { context,size in
            let profiles=LabBoardLayout.profiles(count:state.stacks.count)
            let homes=LabBoardLayout.homes(count:state.stacks.count)
            let layout=LabClassicLayout(size:size,vesselCount:profiles.count)
            let camera=LabBoardLayout.camera(aspect:Float(size.width/max(size.height,1)),azimuth:orbit,vesselCount:profiles.count)
            for index in state.stacks.indices {
                let stack=state.stacks[index]
                guard !uncapped.contains(index),stack.count==state.capacity,let first=stack.first,
                      stack.allSatisfy({state.colors[$0]==state.colors[first]}) else { continue }
                let profile=profiles[index]
                // Planar vessels are rescaled to preserve area per unit.
                let height=profile.height
                let radius=(presentation == .fluid2D ? planarProfiles[index].radius(height):profile.radii.last!)+0.065
                let color=FluidBoardSession.color(state.colors[first])
                func project(_ point:SIMD3<Float>)->CGPoint {
                    if presentation == .fluid {
                        let p=camera.0*SIMD4(homes[index]+point,1)
                        return CGPoint(x:CGFloat(p.x/p.w+1)*size.width/2,y:CGFloat(1-p.y/p.w)*size.height/2)
                    }
                    let base=layout.base(index)
                    return CGPoint(x:base.x+CGFloat(point.x)*layout.scale,y:base.y-CGFloat(point.y-point.z*0.23)*layout.scale)
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
                let bottom=ring(height-0.015,radius),top=ring(height+0.18,radius)
                let eye=presentation == .fluid ? camera.2-homes[index]:SIMD3<Float>(0,5,20)
                // Paint the far side first so the cap retains the board perspective.
                let sides=(0..<48).sorted { simd_dot(bottom[$0],eye)<simd_dot(bottom[$1],eye) }
                for n in sides {
                    let next=(n+1)%48,face=path([bottom[n],bottom[next],top[next],top[n]])
                    let angle=(Float(n)+0.5)*2*Float.pi/48
                    let light=max(0,-cos(angle)*0.55+sin(angle)*0.45)
                    context.fill(face,with:.color(color))
                    context.fill(face,with:.color(.black.opacity(Double(0.48-light*0.40))))
                    // Fine grip grooves suggest a sealed metal stopper rather than a glow.
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
        }
    }
}

/// Touch-down feedback does not wait for the button action on release.
private struct LabVialPressStyle:ButtonStyle {
    func makeBody(configuration:Configuration)->some View {
        configuration.label.overlay {
            RoundedRectangle(cornerRadius:16).fill(.white.opacity(configuration.isPressed ? 0.09:0))
                .overlay(RoundedRectangle(cornerRadius:16).stroke(.white.opacity(configuration.isPressed ? 0.4:0),lineWidth:1))
        }
    }
}
